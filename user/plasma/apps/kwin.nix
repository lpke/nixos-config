# These settings are imported and merged into the rest of the plasma-manager config

{
  kwin = {
    virtualDesktops = {
      number = 6;
      rows = 1;
    };

    effects = {
      desktopSwitching.animation = "off"; # default: "slide"
      hideCursor.enable = true; # hide cursor when typing
      shakeCursor.enable = false; # do not grow cursor when shaken
    };
  };

  configFile = {
    kwinrc = {
      TabBox.MultiScreenMode = 1; # meta+tab only shows windows for current screen and virtual desktop

      # disable screen edge activation
      Plugins.screenedgeEnabled = false;
      "Effect-overview".BorderActivate = 9; # disable screen edge activation

      # SYSTEM SETTINGS > WINDOW BEHAVIOR...

      # Clicking: Window Titlebar (> Titlebar Actions)
      # any titlebar
      Windows.TitlebarDoubleClickCommand = "Maximize (vertical only)"; # double-click
      MouseBindings.CommandTitlebarWheel = "Raise/Lower"; # scroll
      # active titlebar
      MouseBindings.CommandActiveTitlebar1 = "Raise"; # left click
      MouseBindings.CommandActiveTitlebar2 = "Nothing"; # middle click
      MouseBindings.CommandActiveTitlebar3 = "Operations menu"; # right click
      # inactive titlebar
      MouseBindings.CommandInactiveTitlebar1 = "Activate and raise"; # left click
      MouseBindings.CommandInactiveTitlebar2 = "Nothing"; # middle click
      MouseBindings.CommandInactiveTitlebar3 = "Operations menu"; # right click
      # maximise button
      Windows.MaximizeButtonLeftClickCommand = "Maximize"; # left click
      Windows.MaximizeButtonMiddleClickCommand = "Maximize (vertical only)"; # middle click
      Windows.MaximizeButtonRightClickCommand = "Maximize (horizontal only)"; # right click

      # Clicking: Inactive Windows (> Window Actions)
      MouseBindings.CommandWindow1 = "Activate, raise and pass click"; # left click
      MouseBindings.CommandWindow2 = "Activate and pass click"; # middle click
      MouseBindings.CommandWindow3 = "Activate and pass click"; # right click
      MouseBindings.CommandWindowWheel = "Scroll"; # scroll

      # Modifier+Clicking: Any Window (> Window Actions)
      MouseBindings.CommandAllKey = "Meta"; # modifier
      MouseBindings.CommandAll1 = "Activate, raise and move"; # mod+left click
      # MouseBindings.CommandAll2 = "Operations menu"; # mod+middle click
      MouseBindings.CommandAll2 = "Activate, raise and move"; # TEMP: see if meta+middle moves window
      MouseBindings.CommandAll3 = "Resize"; # mod+right click
      MouseBindings.CommandAllWheel = "Raise/Lower"; # mod+scroll
    };
  };
}
