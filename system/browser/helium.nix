{ config, lib, pkgs, ... }:

let
  cfg = config.programs.helium;
  chromiumWrapper = import ./chromium-wrapper.nix { inherit lib; };
  inherit (chromiumWrapper) wrapChromiumBrowser;

  heliumPackage = pkgs.callPackage ../../pkgs/helium {
    inherit (cfg) version hash;
  };

  helium = wrapChromiumBrowser pkgs {
    name = "helium-chromium-flags";
    package = heliumPackage;
    binary = "helium";
    desktopFiles = [ "helium.desktop" ];
    flags = lib.unique config.programs.chromiumBrowserFlags.flags;
  };
in
{
  options.programs.helium = {
    enable = lib.mkEnableOption "Helium Browser";

    version = lib.mkOption {
      type = lib.types.str;
      description = "Helium Browser version to install from GitHub releases.";
    };

    hash = lib.mkOption {
      type = lib.types.str;
      description = "SRI sha256 hash for the pinned Helium AppImage.";
    };

    checkForUpdates = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Check GitHub releases during NixOS activation and print a notice when a newer Helium version exists.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      environment.systemPackages = [ helium ];
    }

    (lib.mkIf cfg.checkForUpdates {
      system.activationScripts.zzzHeliumUpdateNotice.text = ''
        current="${cfg.version}"
        latest="$(
          {
            ${lib.getExe pkgs.curl} -fsSL \
              --connect-timeout 2 \
              --max-time 5 \
              -H 'Accept: application/vnd.github+json' \
              https://api.github.com/repos/imputnet/helium-linux/releases/latest |
              ${lib.getExe pkgs.jq} -r '.tag_name // empty'
          } 2>/dev/null || true
        )"

        if [ -n "$latest" ] && [ "$latest" != "$current" ]; then
          echo "Helium update available: $current -> $latest" >&2
          echo "Update pin: pkgs/helium/update.sh $latest" >&2
        fi
      '';
    })
  ]);
}
