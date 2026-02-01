# These settings are imported and merged into the rest of the plasma-manager config

let
  systemFont = "Noto Sans";
  systemFontMono = "JetBrainsMono Nerd Font Mono";

in
  {
  # System Settings > Text & Fonts
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

  configFile = {
    kdeglobals = {
      General = {
        # Global anti-aliasing settings
        XftAntialias = true;
        XftHintStyle = "hintslight";
        XftSubPixel = "rgb";
      };
    };
  };
}
