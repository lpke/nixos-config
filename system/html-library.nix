{ config, lib, pkgs, ... }:

let
  cfg = config.services.htmlLibrary;
  home = config.users.users.${cfg.user}.home;
  command = [ "${pkgs.python313}/bin/python3" cfg.launcher "--profile" cfg.profile ];
in
{
  options.services.htmlLibrary = {
    enable = lib.mkEnableOption "the private HTML library backend";
    user = lib.mkOption {
      type = lib.types.str;
      default = "luke";
      description = "Owner of the existing HTML library and chezmoi runtime.";
    };
    launcher = lib.mkOption {
      type = lib.types.str;
      default = "${home}/.local/bin/html";
      description = "Installed chezmoi HTML launcher.";
    };
    profile = lib.mkOption {
      type = lib.types.str;
      default = "${home}/.config/tailscale-config/html-library.json";
      description = "Private runtime profile with library root, loopback port and public origin.";
    };
  };

  # Preparation only: the option defaults to false. This module never configures Serve or firewall rules.
  config = lib.mkIf cfg.enable {
    systemd.services.html-library = {
      description = "Private HTML library backend";
      wantedBy = [ "multi-user.target" ];
      after = [ "local-fs.target" ];
      unitConfig.RequiresMountsFor = [ home ];
      unitConfig.ConditionPathExists = [ cfg.launcher cfg.profile ];
      path = [ pkgs.nodejs_24 pkgs.python313 pkgs.git pkgs.glib ];
      environment = {
        HOME = home;
        XDG_DATA_HOME = "${home}/.local/share";
      };
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = config.users.users.${cfg.user}.group;
        WorkingDirectory = home;
        ExecStartPre = lib.escapeShellArgs (command ++ [ "--check" ]);
        ExecStart = lib.escapeShellArgs command;
        ExecStartPost = lib.escapeShellArgs (command ++ [ "--wait-ready" "15" ]);
        TimeoutStartSec = 50;
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStopSec = 10;
        NoNewPrivileges = true;
        PrivateTmp = true;
        UMask = "0077";
      };
    };
  };
}
