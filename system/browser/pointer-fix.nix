{ config, lib, ... }:

let
  cfg = config.programs.browserPointerFix;

  # Synergy/KDE/Wayland can expose virtual touch input that makes desktop
  # browsers report tablet-like pointer capabilities to web apps.
  desktopPointerBlinkFlags = "--blink-settings=maxTouchPoints=0,primaryHoverType=2,availableHoverTypes=2,primaryPointerType=4,availablePointerTypes=4";
in
{
  options.programs.browserPointerFix.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Force desktop pointer media queries in browsers affected by virtual touch input.";
  };

  config = lib.mkIf cfg.enable {
    programs.chromiumBrowserFlags.flags = [ desktopPointerBlinkFlags ];

    programs.firefox.preferences = lib.mkIf config.programs.firefox.enable {
      "dom.maxtouchpoints.testing.value" = 0;
      "dom.w3c_touch_events.enabled" = 0;
      "ui.allPointerCapabilities" = 6;
      "ui.primaryPointerCapabilities" = 6;
    };
  };
}
