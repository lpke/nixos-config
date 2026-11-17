{ config, osConfig, ... }:
let
  controls = builtins.head (builtins.filter
    (package: (package.pname or "") == "krohnkite-control") osConfig.environment.systemPackages);
in {
  home.file.".local/bin/krohnkite".source = "${controls}/bin/krohnkite";
  xdg.desktopEntries.krohnkite = {
    name = "Krohnkite";
    comment = "Window tiling and controls";
    exec = "${controls}/bin/krohnkite";
    icon = "${controls}/share/icons/hicolor/scalable/apps/krohnkite.svg";
    terminal = false;
    categories = [ "Utility" ];
    settings.StartupNotify = "false";
  };
  xdg.dataFile."applications/krohnkite.desktop".source =
    "${config.home.path}/share/applications/krohnkite.desktop";
  systemd.user.services.krohnkite-tray = {
    Unit = {
      Description = "Krohnkite tiling controls";
      After = [ "graphical-session.target" "plasma-kwin_wayland.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${controls}/bin/krohnkite-tray";
      ExecStartPost = "${controls}/bin/krohnkite --backend start";
      ExecStopPost = "${controls}/bin/krohnkite --backend stop";
      Restart = "no";
      KillMode = "control-group";
      TimeoutStartSec = 30;
      TimeoutStopSec = 20;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
