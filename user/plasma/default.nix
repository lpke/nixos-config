# ══════════════════════════════════════════════════════════════════
# PLASMA-MANAGER: changes require nixos build and re-log
# ══════════════════════════════════════════════════════════════════
{ lib, osConfig, pkgs }:

let
  withDeps = path: import path { inherit lib; };
  kwinModule = (import ./apps/kwin.nix).kwin;
  spectacleModule = (import ./apps/spectacle.nix).spectacle;
  krunnerModule = (import ./apps/krunner.nix).krunner;
  fontsModule = (import ./apps/fonts.nix).fonts;

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
  fonts = fontsModule;
  kwin = kwinModule;
  spectacle = spectacleModule;
  krunner = krunnerModule;

  # CONFIG CONTROL (low-level handling of KDE config files in nix format)

  configFile = import ./configFile.nix { inherit lib osConfig pkgs; };
  dataFile = withDeps ./dataFile.nix;
}
