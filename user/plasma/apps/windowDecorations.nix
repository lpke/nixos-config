# These settings are imported and merged into the rest of the plasma-manager config

{
  configFile = {
    # Global Theme > Window Decorations > Breeze > Edit
    "breezerc" = {
      Common = {
        OutlineIntensity = "OutlineOff";
        ShadowSize = "ShadowVeryLarge";
      };
      # Window-Specific Overrides (shadow without titlebar)
      "Windeco Exception 0" = {
        ExceptionPattern = "alacritty";
        Enabled = true;
        BorderSize = 0;
        ExceptionType = 0;
        HideTitleBar = true;
        Mask = 0;
      };
      "Windeco Exception 1" = {
        ExceptionPattern = "vivaldi";
        Enabled = true;
        BorderSize = 0;
        ExceptionType = 0;
        HideTitleBar = true;
        Mask = 0;
      };
      "Windeco Exception 2" = {
        ExceptionPattern = "net-runelite-client-RuneLite";
        Enabled = true;
        BorderSize = 0;
        ExceptionType = 0;
        HideTitleBar = true;
        Mask = 0;
      };
    };
  };
}
