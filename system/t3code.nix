{ config, lib, pkgs, ... }:

let
  cfg = config.programs.t3code;
  t3codePackage = pkgs.callPackage ../pkgs/t3code {};
  updater = pkgs.callPackage ../pkgs/t3code/update.nix {};
in
{
  options.programs.t3code = {
    enable = lib.mkEnableOption "T3 Code";

    checkForUpdates = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Check GitHub releases during NixOS activation and print a notice when a newer T3 Code version exists.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      environment.systemPackages = [ t3codePackage updater ];
    }

    (lib.mkIf cfg.checkForUpdates {
      system.activationScripts.zzzT3CodeUpdateNotice.text = ''
        current=${lib.escapeShellArg t3codePackage.version}
        latest="$(
          {
            ${lib.getExe pkgs.curl} -fsSL \
              --connect-timeout 2 \
              --max-time 5 \
              -H 'Accept: application/vnd.github+json' \
              https://api.github.com/repos/pingdotgg/t3code/releases/latest |
              ${lib.getExe pkgs.jq} -r '.tag_name // empty | sub("^v"; "")'
          } 2>/dev/null || true
        )"

        if [ -n "$latest" ] && [ "$latest" != "$current" ]; then
          {
            printf '\033[33m'
            printf 'T3 Code update available: %s -> %s\n' "$current" "$latest"
            printf 'To update the pinned version, run: update-t3code\n'
            printf '\033[0m'
          } >&2
        fi
      '';
    })
  ]);
}
