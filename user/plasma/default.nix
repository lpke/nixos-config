# ══════════════════════════════════════════════════════════════════
# PLASMA-MANAGER: changes require nixos build and re-log
# ══════════════════════════════════════════════════════════════════
{ lib }:

let
  withDeps = path: import path { inherit lib; };
  kwinModule = (import ./apps/kwin.nix).kwin;
in
  {
  # MODULES (high-level plasma-manager provided settings)
  # https://github.com/nix-community/plasma-manager/tree/trunk/modules

  workspace = {
    colorScheme = "BreezeDark";
    wallpaper = null; # set non-declaratively
  };

  shortcuts = withDeps ./shortcuts.nix;
  panels = withDeps ./panels.nix;
  window-rules = withDeps ./window-rules.nix;
  kwin = kwinModule;

  # CONFIG CONTROL (low-level handling of KDE config files in nix format)

  configFile = withDeps ./configFile.nix;
  dataFile = withDeps ./dataFile.nix;
}
