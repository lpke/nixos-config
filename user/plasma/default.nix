# ══════════════════════════════════════════════════════════════════
# PLASMA-MANAGER: changes require nixos build and re-log
# ══════════════════════════════════════════════════════════════════
{ lib }:

let
  withDeps = path: import path { inherit lib; };
in
{
  shortcuts = withDeps ./shortcuts.nix;
  panels = withDeps ./panels.nix;
  window-rules = withDeps ./window-rules.nix;
  configFile = withDeps ./configFile.nix;
  dataFile = withDeps ./dataFile.nix;

  workspace = {
    colorScheme = "BreezeDark";
    wallpaper = null; # set non-declaratively
  };

  kwin = {
    effects.desktopSwitching.animation = "off"; # default: "slide"
  };
}
