{ config, pkgs, ... }:
let
  quake = pkgs.callPackage ../pkgs/t3-quake {};
in
{
  home.packages = [ quake ];
  home.file.".local/bin/t3-quake".source = "${quake}/bin/t3-quake";
  programs.plasma = {
    configFile.kwinrc.Plugins.t3-quakeEnabled = true;
    configFile.kwinrc.Plugins.t3-quake-slideEnabled = true;
    shortcuts."services/t3-quake.desktop"._launch = "Alt+`";
  };
  xdg.dataFile = {
    "kwin/scripts/t3-quake".source = "${quake}/share/kwin/scripts/t3-quake";
    "kwin/effects/t3-quake-slide".source = "${quake}/share/kwin/effects/t3-quake-slide";
    "dbus-1/services/io.github.lpke.T3Quake.service".text = ''
      [D-BUS Service]
      Name=io.github.lpke.T3Quake
      Exec=${quake}/bin/t3-quake-daemon
      SystemdService=t3-quake.service
    '';
    "applications/t3-quake.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=T3 quake
      Comment=Toggle T3 Code as a drop-down window
      Exec=${config.home.homeDirectory}/.local/bin/t3-quake
      Icon=t3code
      NoDisplay=true
      StartupNotify=false
    '';
  };
  systemd.user.services.t3-quake = {
    Unit = {
      Description = "T3 quake placeholder and window control";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "dbus";
      BusName = "io.github.lpke.T3Quake";
      ExecStart = "${quake}/bin/t3-quake-daemon";
      # KWin restores the real window if this process exits or stalls.
      Restart = "no";
      TimeoutStopSec = 3;
    };
  };
  systemd.user.services.t3-quake-error = {
    Unit.Description = "Report a T3 quake error without interrupting T3";
    Service = {
      Type = "oneshot";
      ExecStart = "${quake}/bin/t3-quake-error";
    };
  };
}
