{ config, pkgs, ... }:
let
  monitorControl = pkgs.callPackage ../pkgs/monitor-control {};
  compatibility = pkgs.callPackage ../pkgs/display-brightness-toggle {};
in
{
  home.packages = [ monitorControl compatibility ];
  # Integrated HM's useUserPackages profile updates only during a system switch.
  # These links and the desktop entry also work after manual HM activation.
  home.file.".local/bin/monitor-control".source = "${monitorControl}/bin/monitor-control";
  home.file.".local/bin/display-brightness-toggle".source = "${compatibility}/bin/display-brightness-toggle";
  xdg.desktopEntries.monitor-control = {
    name = "Monitor control";
    comment = "Monitor blackout and identification";
    exec = "${monitorControl}/bin/monitor-control";
    icon = "${monitorControl}/share/icons/hicolor/scalable/apps/monitor-control.svg";
    terminal = false;
    categories = [ "Utility" ];
    settings.StartupNotify = "false";
    actions.toggle-blackout = {
      name = "Toggle selected monitor blackout";
      # KGlobalAccel caches desktop actions. Keep this path stable across builds.
      exec = "${config.home.homeDirectory}/.local/bin/monitor-control toggle";
    };
  };
  # Shadow the profile entry when useUserPackages needs a system switch.
  xdg.dataFile."applications/monitor-control.desktop".source =
    "${config.home.path}/share/applications/monitor-control.desktop";
  systemd.user.services.monitor-control = {
    Unit = {
      Description = "Monitor control tray and blackout controller";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${monitorControl}/bin/monitor-control-daemon";
      Restart = "on-failure";
      RestartSec = 2;
      TimeoutStopSec = 5;
      KillMode = "control-group";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
