{ config, lib, pkgs, ... }:

let
  cfg = config.programs.postman;
  postmanPackage = pkgs.callPackage ../pkgs/postman {
    inherit (cfg) version hash;
  };
in
{
  options.programs.postman = {
    enable = lib.mkEnableOption "Postman";

    version = lib.mkOption {
      type = lib.types.str;
      description = "Postman version to install from the official download service.";
    };

    hash = lib.mkOption {
      type = lib.types.str;
      description = "SRI sha256 hash for the pinned Postman archive.";
    };

    checkForUpdates = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Check Postman's update service during NixOS activation and print a notice when a newer version exists.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      environment.systemPackages = [ postmanPackage ];
    }

    (lib.mkIf cfg.checkForUpdates {
      system.activationScripts.zzzPostmanUpdateNotice.text = ''
        current=${lib.escapeShellArg cfg.version}
        latest="$(
          {
            ${lib.getExe pkgs.curl} -fsSL \
              --connect-timeout 2 \
              --max-time 5 \
              --get \
              --data-urlencode "currentVersion=$current" \
              --data-urlencode 'platform=linux_64' \
              https://dl.pstmn.io/update/status |
              ${lib.getExe pkgs.jq} -r '.version // empty'
          } 2>/dev/null || true
        )"

        if [ -n "$latest" ] && [ "$latest" != "$current" ]; then
          {
            printf '\033[33m'
            printf 'Postman update available: %s -> %s\n' "$current" "$latest"
            printf 'To update the pinned version, run: update-postman (latest | %s)\n' "$latest"
            printf '\033[0m'
          } >&2
        fi
      '';
    })
  ]);
}
