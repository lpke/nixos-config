# These settings are imported and merged into the rest of the plasma-manager config

{
  # Decoration-related window rules (disable or enable all)
  window-rules = [
    # allow border for discord to enable shadow (hidden by app by default)
    # titlebar is hidden with window override in breeze config
    # result is a border shadow added back while keeping titlebar hidden
    {
      description = "Discord";
      match = {
        window-class = {
          value = "discord discord";
          type = "exact";
        };
      };
      apply = {
        noborder = {
          value = false;
          apply = "initially";
        };
      };
    }
  ];

  configFile = {
    # Global Theme > Window Decorations > Breeze > Edit
    "breezerc" = {
      Common = {
        OutlineIntensity = "OutlineOff";
        ShadowSize = "ShadowVeryLarge";
      };
      # Window-Specific Overrides (keep shadow, hide titlebar)
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
