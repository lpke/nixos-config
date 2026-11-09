{ pkgs, ... }:
let
  tray = pkgs.callPackage ../pkgs/t3-tray {};
  app = pkgs.makeDesktopItem {
    name = "t3-controls";
    desktopName = "T3 Controls";
    comment = "Connection and Git review tray controls";
    exec = "${tray}/bin/t3-tray show";
    icon = "${tray}/share/icons/hicolor/scalable/apps/t3-controls.svg";
    categories = [ "Utility" ];
    startupNotify = false;
  };
in
{
  home.file.".local/bin/t3-tray".source = "${tray}/bin/t3-tray";
  xdg.dataFile."applications/t3-controls.desktop".source =
    "${app}/share/applications/t3-controls.desktop";
  systemd.user.services.t3-tray = {
    Unit = {
      Description = "T3 connections and Git review launcher status and controls";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${tray}/bin/t3-tray-daemon";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
