{ config, lib, pkgs, ... }:
let
  controller = pkgs.callPackage ../../pkgs/xremap-mode-controller {};
  kwinScript = pkgs.writeText "xremap-mode-controller.js" (
    builtins.readFile ../../pkgs/xremap-mode-controller/kwin.js
  );
in
{
  systemd.user.services.xremap-mode-controller = {
    Unit = {
      Description = "Control xremap mode from Synergy and TigerVNC";
      After = [
        "graphical-session.target"
        "plasma-kwin_wayland.service"
        "xremap.service"
        "ydotoold.service"
      ];
      Wants = [
        "xremap.service"
        "ydotoold.service"
      ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = lib.escapeShellArgs [
        "${controller}/bin/xremap-mode-controller"
        "--synergy-log"
        "${config.home.homeDirectory}/.var/app/com.symless.synergy/.local/state/Synergy/synergy.log"
        "--local-screen"
        "lpnix-1d83cd06"
        "--ydotool"
        "${pkgs.ydotool}/bin/ydotool"
        "--kwin-script"
        "${kwinScript}"
        "--state-file"
        "%t/xremap-mode-controller/state"
      ];
      Restart = "on-failure";
      RestartSec = 1;
      RuntimeDirectory = "xremap-mode-controller";
      TimeoutStopSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Reassert the selected mode if xremap restarts independently.
  systemd.user.services.xremap.Service.ExecStartPost =
    "${pkgs.systemd}/bin/systemctl --user --no-block try-restart xremap-mode-controller.service";
}
