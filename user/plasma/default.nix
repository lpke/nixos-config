# ══════════════════════════════════════════════════════════════════
# PLASMA-MANAGER: changes require nixos build and re-log
# ══════════════════════════════════════════════════════════════════
{ lib }:

let
  withDeps = path: import path { inherit lib; };
  kwinModule = (import ./apps/kwin.nix).kwin;
  spectacleModule = (import ./apps/spectacle.nix).spectacle;
  krunnerModule = (import ./apps/krunner.nix).krunner;

  systemFont = "Noto Sans";
  systemFontMono = "JetBrainsMono Nerd Font Mono";

in
  {
  # MODULES (high-level plasma-manager provided settings)
  # https://github.com/nix-community/plasma-manager/tree/trunk/modules

  workspace = {
    colorScheme = "BreezeDark";
    wallpaper = null; # set non-declaratively
  };

  # System Settings > Text & Fonts
  # (for global anti-aliasing settings, see `kdeglobals` in `configFile.nix`)
  fonts = {
    general = {
      family = systemFont;
      pointSize = 11;
      weight = "normal"; # 400
    };
    fixedWidth = {
      family = systemFontMono;
      pointSize = 12;
      weight = "normal";
    };
    small = {
      family = systemFont;
      pointSize = 9;
      weight = "normal";
    };
    toolbar = {
      family = systemFont;
      pointSize = 11;
      weight = "normal";
    };
    menu = {
      family = systemFont;
      pointSize = 11;
      weight = "normal";
    };
    windowTitle = {
      family = systemFont;
      pointSize = 10;
      weight = "normal";
    };
  };

  shortcuts = withDeps ./shortcuts.nix;
  panels = withDeps ./panels.nix;
  window-rules = withDeps ./window-rules.nix;
  kwin = kwinModule;
  spectacle = spectacleModule;
  krunner = krunnerModule;

  # CONFIG CONTROL (low-level handling of KDE config files in nix format)

  configFile = withDeps ./configFile.nix;
  dataFile = withDeps ./dataFile.nix;
}
