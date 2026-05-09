{ config, lib, pkgs, ... }:

let
  fanControl = import ./fan-control-config.nix { inherit lib; };
  smoothSourceNames = lib.attrNames fanControl.grid.smoothSources;
  validGridSources = [
    "cpu"
    "liquid"
    "gpu"
    "max"
    "max_smooth"
  ] ++ smoothSourceNames;
  configuredGridSources =
    map (settings: settings.source) (lib.attrValues fanControl.grid.channels);
  smoothSourceConfigs = lib.attrValues fanControl.grid.smoothSources;

  curveArgs = curve:
    lib.concatStringsSep " " (lib.concatMap
      (point: [ (toString point.temp) (toString point.percent) ])
      curve);

  gridDevicePaths = [
    "/dev/${fanControl.grid.deviceSymlink}"
    "/dev/serial/by-id/usb-Microchip_Technology_Inc._MCP2200_USB_Serial_Port_Emulator_${fanControl.grid.serial}-if00"
  ];

  ksystemstatsCustomSensors =
    import ../pkgs/ksystemstats-custom-sensors {
      inherit lib pkgs;
    };

  gridfanapi = pkgs.python313Packages.buildPythonPackage rec {
    pname = "gridfanapi";
    version = "1.0.0";
    format = "setuptools";

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-twWXm136Y0FRcHOqKJh7PGIyb5RO0irvvGNjuZ13TrE=";
    };

    propagatedBuildInputs = with pkgs.python313Packages; [
      pyserial
    ];

    doCheck = false;

    meta = {
      description = "NZXT Grid+ V2 fan controller protocol library";
      homepage = "https://pypi.org/project/gridfanapi/";
      license = lib.licenses.gpl3Plus;
      platforms = lib.platforms.linux;
    };
  };

  gridPython = pkgs.python313.withPackages (_: [ gridfanapi ]);

  gridConfigFile = pkgs.writeText "nzxt-grid-v2-fan-control.json" (builtins.toJSON {
    devicePaths = gridDevicePaths;
    statusDir = "/run/nzxt-grid-v2";
    inherit (fanControl.grid) controlIntervalSeconds hysteresisPercent smoothSources;
    nvidiaSmi = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";
    channels = lib.mapAttrsToList
      (channel: settings: {
        inherit channel;
        inherit (settings) name source curve;
      })
      fanControl.grid.channels;
  });

  gridControlScript = pkgs.writeTextFile {
    name = "nzxt-grid-v2-fan-control";
    executable = true;
    text = ''
      #!${gridPython}/bin/python
      import json
      import logging
      import os
      from pathlib import Path
      import signal
      import subprocess
      import sys
      import time

      from gridfanapi import GridFanAPI, GridFanError

      with open("${gridConfigFile}", "r", encoding="utf-8") as config_file:
          CONFIG = json.load(config_file)

      logging.basicConfig(
          level=logging.INFO,
          format="%(asctime)s %(levelname)s %(message)s",
      )
      log = logging.getLogger("nzxt-grid-v2-fan-control")
      stop_requested = False


      def handle_stop(_signum, _frame):
          global stop_requested
          stop_requested = True


      signal.signal(signal.SIGINT, handle_stop)
      signal.signal(signal.SIGTERM, handle_stop)


      def read_text(path):
          return Path(path).read_text(encoding="utf-8").strip()


      def hwmon_temp(device_name, label=None):
          for hwmon in sorted(Path("/sys/class/hwmon").glob("hwmon*")):
              try:
                  if read_text(hwmon / "name") != device_name:
                      continue
                  if label is None:
                      return int(read_text(hwmon / "temp1_input")) / 1000.0
                  for label_path in sorted(hwmon.glob("temp*_label")):
                      if read_text(label_path) == label:
                          input_path = label_path.with_name(
                              label_path.name.replace("_label", "_input")
                          )
                          return int(read_text(input_path)) / 1000.0
              except (OSError, ValueError):
                  continue
          return None


      def gpu_temp():
          nvidia_smi = CONFIG["nvidiaSmi"]
          if not os.path.exists(nvidia_smi):
              return None
          try:
              output = subprocess.check_output(
                  [
                      nvidia_smi,
                      "--query-gpu=temperature.gpu",
                      "--format=csv,noheader,nounits",
                  ],
                  text=True,
                  timeout=2,
              )
              first_line = output.strip().splitlines()[0]
              return float(first_line)
          except (subprocess.SubprocessError, IndexError, ValueError):
              return None


      def alpha(value):
          try:
              return max(0.0, min(1.0, float(value)))
          except (TypeError, ValueError):
              return 1.0


      def update_smoothed_source(name, raw_value, state):
          if raw_value is None:
              state.pop(name, None)
              return None

          previous = state.get(name)
          if previous is None:
              state[name] = raw_value
              return raw_value

          settings = CONFIG["smoothSources"][name]
          selected_alpha = alpha(
              settings["riseAlpha"]
              if raw_value > previous
              else settings["fallAlpha"]
          )
          smoothed = previous + selected_alpha * (raw_value - previous)
          state[name] = smoothed
          return smoothed


      def control_temperatures(smooth_state):
          values = {
              "cpu": hwmon_temp("coretemp", "Package id 0"),
              "liquid": hwmon_temp("z53", "Coolant temp"),
              "gpu": gpu_temp(),
          }
          available = [value for value in values.values() if value is not None]
          values["max"] = max(available) if available else None

          for name, settings in CONFIG["smoothSources"].items():
              values[name] = update_smoothed_source(
                  name,
                  values.get(settings["rawSource"]),
                  smooth_state,
              )

          max_smooth_values = [
              values.get("cpu_smooth"),
              values.get("gpu_smooth"),
              values.get("liquid"),
          ]
          available_smoothed = [
              value for value in max_smooth_values if value is not None
          ]
          values["max_smooth"] = (
              max(available_smoothed) if available_smoothed else None
          )
          return values


      def interpolate(curve, temp):
          points = sorted(curve, key=lambda point: point["temp"])
          if temp <= points[0]["temp"]:
              return points[0]["percent"]
          for lower, upper in zip(points, points[1:]):
              if temp <= upper["temp"]:
                  span = upper["temp"] - lower["temp"]
                  if span <= 0:
                      return upper["percent"]
                  ratio = (temp - lower["temp"]) / span
                  return lower["percent"] + ratio * (upper["percent"] - lower["percent"])
          return points[-1]["percent"]


      def grid_percent(value):
          if value <= 0:
              return 0
          value = max(20, min(100, value))
          return int(round(value / 5.0) * 5)


      def find_device(seconds=60):
          deadline = time.monotonic() + seconds
          while time.monotonic() < deadline:
              for path in CONFIG["devicePaths"]:
                  if os.path.exists(path):
                      return path
              time.sleep(1)
          return None


      def write_metric(name, value):
          try:
              status_dir = Path(CONFIG["statusDir"])
              status_dir.mkdir(parents=True, exist_ok=True)
              tmp_path = status_dir / f".{name}.tmp"
              tmp_path.write_text(f"{value}\n", encoding="utf-8")
              tmp_path.replace(status_dir / name)
          except OSError as error:
              log.debug("failed to publish %s: %s", name, error)


      def read_grid_metric(default, callback, channel):
          try:
              return callback(channel)
          except Exception as error:
              log.debug("failed to read channel %s metric: %s", channel, error)
              return default


      def publish_channel(grid, channel, target_percent):
          write_metric(
              f"channel_{channel}_rpm",
              read_grid_metric(0, grid.get_fan_rpm, channel),
          )
          write_metric(
              f"channel_{channel}_percent",
              read_grid_metric(0, grid.get_fan_percent, channel),
          )
          write_metric(
              f"channel_{channel}_voltage",
              read_grid_metric(0.0, grid.get_fan_voltage, channel),
          )
          write_metric(
              f"channel_{channel}_wattage",
              read_grid_metric(0.0, grid.get_fan_wattage, channel),
          )
          write_metric(f"channel_{channel}_target_percent", target_percent)


      def controller(device):
          return GridFanAPI(
              device_name=os.path.basename(device),
              dir=os.path.dirname(device),
              log_level="WARNING",
          )


      def main():
          device = find_device()
          if device is None:
              log.error(
                  "Grid+ V2 device did not appear at any expected path: %s",
                  ", ".join(CONFIG["devicePaths"]),
              )
              return 1

          grid = controller(device)
          if not grid.init():
              log.error("Grid+ V2 did not respond to initialization")
              return 1

          log.info("Grid+ V2 control active using %s", device)
          last_percent = {}
          smooth_state = {}

          while not stop_requested:
              temps = control_temperatures(smooth_state)
              log.debug("temperatures: %s", temps)
              target_percent = {str(channel): 0 for channel in range(1, 7)}

              for channel in CONFIG["channels"]:
                  source = channel["source"]
                  temp = temps.get(source)
                  if temp is None:
                      log.warning(
                          "channel %s %s skipped: no %s temperature",
                          channel["channel"],
                          channel["name"],
                          source,
                      )
                      continue

                  desired = grid_percent(interpolate(channel["curve"], temp))
                  target_percent[channel["channel"]] = desired
                  previous = last_percent.get(channel["channel"])
                  changed = (
                      previous is None
                      or abs(desired - previous) >= CONFIG["hysteresisPercent"]
                  )

                  if changed:
                      try:
                          grid.set_fan(int(channel["channel"]), desired)
                      except GridFanError as error:
                          log.error(
                              "channel %s %s failed: %s",
                              channel["channel"],
                              channel["name"],
                              error,
                          )
                          continue
                      last_percent[channel["channel"]] = desired
                      log.info(
                          "channel %s %s -> %s%% from %s %.1f C",
                          channel["channel"],
                          channel["name"],
                          desired,
                          source,
                          temp,
                      )

              for channel in range(1, 7):
                  publish_channel(
                      grid,
                      channel,
                      target_percent.get(str(channel), last_percent.get(str(channel), 0)),
                  )

              time.sleep(CONFIG["controlIntervalSeconds"])

          return 0


      if __name__ == "__main__":
          sys.exit(main())
    '';
  };

  gridStatusScript = pkgs.writeTextFile {
    name = "nzxt-grid-v2-status";
    destination = "/bin/nzxt-grid-v2-status";
    executable = true;
    text = ''
      #!${gridPython}/bin/python
      import os
      import sys

      from gridfanapi import GridFanAPI

      DEVICE_PATHS = ${builtins.toJSON gridDevicePaths}
      NAMES = ${builtins.toJSON (lib.mapAttrs (_: settings: settings.name) fanControl.grid.channels)}
      SOURCES = ${builtins.toJSON (lib.mapAttrs (_: settings: settings.source) fanControl.grid.channels)}

      def find_device():
          for path in DEVICE_PATHS:
              if os.path.exists(path):
                  return path
          return None

      DEVICE = find_device()
      if DEVICE is None:
          print("Grid+ V2 does not exist at any expected path:")
          for path in DEVICE_PATHS:
              print(f"  {path}")
          print("Rebuild/reboot or reload/trigger udev rules if only /dev/GridPlusV2 is missing.")
          sys.exit(1)

      grid = GridFanAPI(
          device_name=os.path.basename(DEVICE),
          dir=os.path.dirname(DEVICE),
          log_level="ERROR",
      )

      print(f"Grid+ V2: {DEVICE}")
      print(f"{'channel':>7}  {'name':<24} {'source':<10} {'rpm':>6} {'volt':>6} {'pct':>5} {'watt':>5}")
      grid.init()
      for channel in range(1, 7):
          name = NAMES.get(str(channel), "unused")
          source = SOURCES.get(str(channel), "-")
          rpm = grid.get_fan_rpm(channel)
          voltage = grid.get_fan_voltage(channel)
          percent = grid.get_fan_percent(channel)
          wattage = grid.get_fan_wattage(channel)
          print(f"{channel:>7}  {name:<24} {source:<10} {rpm:>6} {voltage:>5.1f}V {percent:>4}% {wattage:>4.1f}W")
    '';
  };

in
assert lib.assertMsg
  (lib.all (source: lib.elem source validGridSources) configuredGridSources)
  "Grid+ V2 channel source must be one of: ${lib.concatStringsSep ", " validGridSources}";
assert lib.assertMsg
  (lib.all (settings: lib.elem settings.rawSource [ "cpu" "liquid" "gpu" ]) smoothSourceConfigs)
  "Grid+ V2 smooth source rawSource must be one of: cpu, liquid, gpu";
assert lib.assertMsg
  (lib.all
    (settings:
      settings.riseAlpha > 0 && settings.riseAlpha <= 1
      && settings.fallAlpha > 0 && settings.fallAlpha <= 1)
    smoothSourceConfigs)
  "Grid+ V2 smoothing alphas must be greater than 0 and less than or equal to 1";
{
  # Declarative replacement for the mutable /etc/sysconfig/lm_sensors file
  # created by `sensors-detect`. This only exposes motherboard sensors.
  boot.kernelModules = [ "nct6775" ];

  environment.systemPackages = [
    gridStatusScript
    ksystemstatsCustomSensors
  ];

  systemd.tmpfiles.rules = [
    "d /run/nzxt-grid-v2 0755 root root -"
  ];

  services.udev.packages = [ pkgs.liquidctl ];
  services.udev.extraRules = ''
    # NZXT Grid+ V2: Microchip MCP2200 serial bridge, serial 0002042774.
    ACTION=="add", SUBSYSTEM=="tty", SUBSYSTEMS=="usb", ATTRS{idVendor}=="04d8", ATTRS{idProduct}=="00df", ATTRS{serial}=="${fanControl.grid.serial}", GROUP="fancontrol", MODE="0660", SYMLINK+="${fanControl.grid.deviceSymlink}"
  '';

  users.groups.fancontrol.members = [ "luke" ];

  systemd.services.nzxt-kraken-z53-fan-control = {
    description = "Apply NZXT Kraken Z53 pump and radiator fan curves";
    wantedBy = [ "multi-user.target" ];
    wants = [ "systemd-udev-settle.service" ];
    after = [ "systemd-udev-settle.service" ];

    path = [ pkgs.liquidctl ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -euo pipefail

      liquidctl --match "${fanControl.kraken.liquidctlMatch}" initialize
      liquidctl --match "${fanControl.kraken.liquidctlMatch}" set pump speed ${curveArgs fanControl.kraken.pumpCurve}
      liquidctl --match "${fanControl.kraken.liquidctlMatch}" set fan speed ${curveArgs fanControl.kraken.radiatorFanCurve}
      liquidctl --match "${fanControl.kraken.liquidctlMatch}" status
    '';
  };

  systemd.services.nzxt-grid-v2-fan-control = {
    description = "Apply NZXT Grid+ V2 case fan curves";
    wantedBy = [ "multi-user.target" ];
    wants = [ "systemd-udev-settle.service" ];
    after = [ "systemd-udev-settle.service" ];

    serviceConfig = {
      ExecStart = "${gridControlScript}";
      Restart = "always";
      RestartSec = "5s";
    };
  };

  powerManagement.resumeCommands = ''
    ${pkgs.systemd}/bin/systemctl restart nzxt-kraken-z53-fan-control.service nzxt-grid-v2-fan-control.service || true
  '';
}
