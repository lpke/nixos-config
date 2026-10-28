{ config, pkgs, ... }:
let
  synergyKeys = pkgs.callPackage ../../pkgs/synergy-keys {};
in
{
  xdg.configFile."synergy-keys/config.json".text = builtins.toJSON {
    local_screen = "lpnix-1d83cd06";
    synergy_log = "${config.home.homeDirectory}/.var/app/com.symless.synergy/.local/state/Synergy/synergy.log";
  };

  # Only the tray's lightweight lifecycle watcher starts with the desktop.
  systemd.user.services.synergy-keys-tray = {
    Unit = {
      Description = "Synergy Mac keyboard status and controls";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${synergyKeys}/bin/synergy-keys-tray";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.synergy-keys-controller = {
    Unit = {
      Description = "Synergy screen detection and Mac keyboard mappings";
      After = [ "xremap.service" "ydotoold.service" ];
      Wants = [ "xremap.service" "ydotoold.service" ];
      PartOf = [ "graphical-session.target" "synergy-keys-tray.service" ];
    };
    Service = {
      ExecStart = "${synergyKeys}/bin/synergy-keys-controller";
      Type = "notify";
      WatchdogSec = 5;
      ExecStopPost = "${synergyKeys}/bin/synergy-keys --reset-local";
      Restart = "on-failure";
      RestartSec = 1;
      RuntimeDirectory = "synergy-keys";
      RuntimeDirectoryMode = "0700";
      RuntimeDirectoryPreserve = "yes";
      TimeoutStopSec = 5;
    };
  };

  # Reassert mappings after an xremap restart from the local screen state.
  systemd.user.services.xremap.Service.ExecStartPost =
    "${synergyKeys}/bin/synergy-keys --reapply";

  # Keep the interactive command aligned with targeted user-service activations.
  home.file.".local/bin/synergy-keys".source = "${synergyKeys}/bin/synergy-keys";
}
