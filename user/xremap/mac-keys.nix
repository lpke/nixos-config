{ config, lib, pkgs, ... }:
let
  macKeys = pkgs.callPackage ../../pkgs/mac-keys {};
  host = "mbp";
in
{
  xdg.configFile."mac-keys/config.json".text = builtins.toJSON {
    inherit host;
    local_screen = "lpnix-1d83cd06";
    synergy_log = "${config.home.homeDirectory}/.var/app/com.symless.synergy/.local/state/Synergy/synergy.log";
    terminal_applications = [ "org.alacritty" "com.googlecode.iterm2" ];
  };

  # Only the tray's lightweight lifecycle watcher starts with the desktop.
  systemd.user.services.mac-keys-tray = {
    Unit = {
      Description = "Synergy Mac keyboard status and controls";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${macKeys}/bin/mac-keys-tray";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.mac-keys-controller = {
    Unit = {
      Description = "Synergy Mac keyboard mappings and app detection";
      After = [ "xremap.service" "ydotoold.service" ];
      Wants = [ "xremap.service" "ydotoold.service" ];
      PartOf = [ "graphical-session.target" "mac-keys-tray.service" ];
    };
    Service = {
      ExecStart = "${macKeys}/bin/mac-keys-controller";
      Type = "notify";
      WatchdogSec = 5;
      ExecStopPost = "${macKeys}/bin/mac-keys --reset-local";
      Restart = "on-failure";
      RestartSec = 1;
      RuntimeDirectory = "mac-keys";
      RuntimeDirectoryMode = "0700";
      RuntimeDirectoryPreserve = "yes";
      TimeoutStopSec = 5;
    };
  };

  # A manually requested connection survives observer and Synergy shutdown.
  # No Restart or idle timeout: failed connections require mac-keys retry.
  systemd.user.services.mac-keys-ssh = {
    Unit = {
      Description = "Cached SSH connection for Synergy Mac keys";
      PartOf = [ "graphical-session.target" ];
      StartLimitIntervalSec = 0;
    };
    Service = {
      ExecStart = lib.escapeShellArgs [
        "${pkgs.openssh}/bin/ssh" "-M" "-N" "-T"
        "-o" "ControlMaster=yes" "-o" "ControlPath=%t/mac-keys-ssh/control"
        "-o" "ControlPersist=no" "-o" "BatchMode=yes" "-o" "ConnectTimeout=5"
        "-o" "ServerAliveInterval=30" "-o" "ServerAliveCountMax=6"
        host
      ];
      RuntimeDirectory = "mac-keys-ssh";
      RuntimeDirectoryMode = "0700";
      TimeoutStopSec = 5;
    };
  };

  # Reassert mappings after an xremap restart without attempting SSH again.
  systemd.user.services.xremap.Service.ExecStartPost =
    "${macKeys}/bin/mac-keys --reapply";
}
