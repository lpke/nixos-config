# ══════════════════════════════════════════════════════════════════
# PLASMA-MANAGER: changes require nixos build and re-log
# ══════════════════════════════════════════════════════════════════
{ lib, osConfig, pkgs }:

let
  callWith = deps: module:
    module (builtins.intersectAttrs (builtins.functionArgs module) deps);
  appDeps = { inherit lib pkgs; };
  moduleDeps = appDeps // { inherit osConfig withApp; };
  withApp = name:
    let app = import (./apps + "/${name}.nix");
    in if builtins.isFunction app then callWith appDeps app else app;
  withDeps = path:
    let module = import path;
    in if builtins.isFunction module then callWith moduleDeps module else module;
  kwinModule = (withApp "kwin").kwin;
  spectacleModule = (withApp "spectacle").spectacle;
  krunnerModule = (withApp "krunner").krunner;
  fontsModule = (withApp "fonts").fonts;

in
  {
  # MODULES (high-level plasma-manager provided settings)
  # https://github.com/nix-community/plasma-manager/tree/trunk/modules

  workspace = {
    colorScheme = "BreezeDark";
    wallpaper = null; # set non-declaratively
  };

  input.keyboard.options = lib.splitString "," osConfig.services.xserver.xkb.options;

  shortcuts = lib.recursiveUpdate (withDeps ./shortcuts.nix) {
    # Retire the old primary-only action, including its cached KService command.
    "plasma-manager-commands.desktop".display-brightness-toggle = [];
    "services/plasma-manager-commands.desktop".display-brightness-toggle = [];
    "monitor-control.desktop".toggle-blackout = "Meta+Ctrl+Alt+Shift+D";
    "services/monitor-control.desktop".toggle-blackout = "Meta+Ctrl+Alt+Shift+D";
  };
  panels = withDeps ./panels.nix;
  window-rules = withDeps ./window-rules.nix;
  fonts = fontsModule;
  kwin = kwinModule;
  spectacle = spectacleModule;
  krunner = krunnerModule;

  # CONFIG CONTROL (low-level handling of KDE config files in nix format)

  configFile = withDeps ./configFile.nix;
  dataFile = withDeps ./dataFile.nix;
}
