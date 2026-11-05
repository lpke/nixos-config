{ pkgs, ... }:
let
  helper = pkgs.callPackage ../pkgs/t3-tailscale {};
in
{
  home.file.".local/bin/t3-tailscale".source = "${helper}/bin/t3-tailscale";
  systemd.user.services.t3-tailscale-tray = {
    Unit = {
      Description = "T3 Tailscale gateway status and controls";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionPathExists = "%h/.config/tailscale-config/t3-gateway.json";
    };
    Service = {
      ExecStart = "${helper}/bin/t3-tailscale-tray";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
