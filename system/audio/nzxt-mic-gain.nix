{ config, lib, pkgs, ... }:

let
  cfg = config.services.pipewire.nzxtMicGain;

  amixer = "${pkgs.alsa-utils}/bin/amixer";
  nzxtMicGain = pkgs.callPackage ../../pkgs/nzxt-mic-gain {
    commandName = cfg.commandName;
    inherit (cfg)
      compactRangeGainPercent
      compactRangeMax
      extendedRangeGainPercent
      extendedRangeMaxes
      fallbackGainPercent
      ;
  };
  nzxtMicGainStatus = pkgs.callPackage ../../pkgs/nzxt-mic-gain {
    commandName = cfg.statusCommand;
    inherit (cfg)
      compactRangeGainPercent
      compactRangeMax
      extendedRangeGainPercent
      extendedRangeMaxes
      fallbackGainPercent
      ;
  };

  serviceName = "nzxt-mic-gain-startup";
  startupScript = pkgs.writeShellScript "nzxt-mic-gain-startup" ''
    set -euo pipefail

    card="${cfg.card}"
    control="${cfg.control}"
    setter="${nzxtMicGain}/bin/${cfg.commandName}"

    attempts=0
    while [ "$attempts" -lt 30 ]; do
      if ${amixer} -c "$card" sget "$control" >/dev/null 2>&1; then
        NZXT_MIC_CARD="$card" NZXT_MIC_CONTROL="$control" "$setter" auto
        exit 0
      fi
      attempts=$((attempts + 1))
      ${pkgs.coreutils}/bin/sleep 0.25
    done

    echo "NZXT USB MIC control not ready (card=$card control=$control)." >&2
    exit 0
  '';
in
{
  options.services.pipewire.nzxtMicGain = {
    enable = lib.mkEnableOption "NZXT USB MIC hardware-gain startup restore";

    card = lib.mkOption {
      type = lib.types.str;
      default = "MIC";
      description = "ALSA card name for NZXT USB MIC controls.";
    };

    control = lib.mkOption {
      type = lib.types.str;
      default = "Mic";
      description = "ALSA capture control that maps to NZXT USB MIC hardware gain.";
    };

    extendedRangeMaxes = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ 233 255 ];
      description = "ALSA Mic Capture Volume max values treated as the extended-range NZXT USB MIC state.";
    };

    compactRangeMax = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "ALSA Mic Capture Volume max value treated as the compact-range NZXT USB MIC state.";
    };

    extendedRangeGainPercent = lib.mkOption {
      type = lib.types.either lib.types.int lib.types.float;
      default = 1;
      description = "Hardware gain percent to apply when the NZXT USB MIC exposes an extended ALSA mixer range.";
    };

    compactRangeGainPercent = lib.mkOption {
      type = lib.types.either lib.types.int lib.types.float;
      default = 100;
      description = "Hardware gain percent to apply when the NZXT USB MIC exposes the 0-100 ALSA mixer range.";
    };

    fallbackGainPercent = lib.mkOption {
      type = lib.types.either lib.types.int lib.types.float;
      default = 100;
      description = "Hardware gain percent to apply when the NZXT USB MIC exposes an unexpected ALSA mixer range.";
    };

    commandName = lib.mkOption {
      type = lib.types.str;
      default = "nzxt-mic-gain";
      description = "Command name for status + set helper.";
    };

    statusCommand = lib.mkOption {
      type = lib.types.str;
      default = "nzxt-mic-gain-status";
      description = "Command name for status only.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          cfg.extendedRangeGainPercent >= 0 && cfg.extendedRangeGainPercent <= 100
          && cfg.compactRangeGainPercent >= 0 && cfg.compactRangeGainPercent <= 100
          && cfg.fallbackGainPercent >= 0 && cfg.fallbackGainPercent <= 100;
        message = "services.pipewire.nzxtMicGain gain percentages must be between 0 and 100.";
      }
      {
        assertion = cfg.extendedRangeMaxes != [] && !(builtins.elem cfg.compactRangeMax cfg.extendedRangeMaxes);
        message = "services.pipewire.nzxtMicGain compactRangeMax must not also appear in extendedRangeMaxes.";
      }
    ];

    systemd.user.services.${serviceName} = {
      description = "Apply NZXT USB MIC hardware gain on user startup";
      wantedBy = [ "default.target" ];
      after = [ "wireplumber.service" "pipewire.service" ];
      partOf = [ "pipewire.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${startupScript}";
        Restart = "on-failure";
        RestartSec = "1s";
      };
      restartIfChanged = true;
    };

    system.userActivationScripts.nzxtMicGain = {
      deps = [];
      text = ''
        ${pkgs.systemd}/bin/systemctl --user start ${lib.escapeShellArg "${serviceName}.service"} >/dev/null 2>&1 || true
      '';
    };

    environment.systemPackages = [
      nzxtMicGain
      nzxtMicGainStatus
    ];
  };
}
