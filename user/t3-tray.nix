{ pkgs, ... }:
let
  tray = pkgs.callPackage ../pkgs/t3-tray {};
in
{
  home.file.".local/bin/t3-tray".source = "${tray}/bin/t3-tray";
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
