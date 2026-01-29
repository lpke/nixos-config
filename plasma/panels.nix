# Overview: https://thedocumentation.org/plasma-manager/configuration/panels/
# Widget config: https://github.com/nix-community/plasma-manager/tree/trunk/modules/widgets
# Tip: Go to source code module for something, and ask AI to parse and present available options

[
  # ══════════════════════════════════════════════════════════════════
  # Primary monitor panel (screen 0)
  # ══════════════════════════════════════════════════════════════════
  {
    screen = 0;
    location = "top";
    alignment = "center"; # doesnt have any effect when full width
    height = 25; # must be odd for window title and global menu text to line up
    opacity = "adaptive";
    hiding = null; # always show by default (null is default)
    # full width (null is defaults)
    offset = null;
    minLength = null;
    maxLength = null;
    lengthMode = null;

    # widgets on the panel - left to right
    widgets = [
      # Icons-only Task Manager
      # {
      #   iconTasks = {
      #     iconsOnly = true;
      #     launchers = []; # no pinned apps
      #     appearance = {
      #       iconSpacing = "large";
      #       indicateAudioStreams = true;
      #       showTooltips = true; # show windows on hover
      #       highlightWindows = true; # reveal hovered window
      #       rows = {
      #         multirowView = "never";
      #       };
      #     };
      #     behavior = {
      #       # sortingMethod = "byHorizontalPosition";
      #       minimizeActiveTaskOnClick = true;
      #       middleClickAction = "newInstance";
      #       unhideOnAttentionNeeded = true;
      #       newTasksAppearOn = "right";
      #       showTasks = {
      #         onlyInCurrentScreen = true;
      #         onlyInCurrentDesktop = true;
      #         onlyInCurrentActivity = true;
      #       };
      #       grouping = {
      #         method = "byProgramName";
      #       };
      #       wheel = {
      #         ignoreMinimizedTasks = true;
      #         switchBetweenTasks = true;
      #       };
      #     };
      #   };
      # }

      # Icons-only Task Manager (raw config as some things above weren't working)
      {
        name = "org.kde.plasma.icontasks";
        config.General = {
          forceStripes = false;
          groupingStrategy = 1;           # byProgramName
          highlightWindows = true;
          iconSpacing = 3;                # large
          indicateAudioStreams = true;
          launchers = "";
          middleClickAction = 2;          # newInstance
          minimizeActiveTaskOnClick = true;
          reverseMode = false;
          showOnlyCurrentActivity = true;
          showOnlyCurrentDesktop = true;
          showOnlyCurrentScreen = true;
          showToolTips = true;
          sortingStrategy = 6;            # <-- changed from 5
          unhideOnAttention = true;
          wheelEnabled = true;
          wheelSkipMinimized = true;
        };
      }

      # Window Title (third-party widget - needs raw config)
      {
        name = "org.kde.windowtitle";
        config = {
          Appearance = {
            activityIcon = false;
            altTxt = "";
            elidePos = 2;
            fillThickness = true;
            fixedLength = 300;
            fontSize = 15;
            isBold = true;
            lastSpace = 6;
            lengthKind = 2;
            midSpace = 16;
            noIcon = true;
            txt = "%a";
            visible = false;
          };
          Substitutions = {
            subsMatchApp = ''"Telegram Desktop","Gimp-.*","soffice.bin","Spotify.*","Plasma Desktop Workspace","java","bolt"'';
            subsMatchTitle = ''".*",".*",".*",".*",".*",".*",".*"'';
            subsReplace = ''"Telegram","Gimp","LibreOffice","Spotify","Desktop Workspace","Java - %w","Bolt Launcher"'';
          };
        };
      }

      # Global Menu (App Menu)
      "org.kde.plasma.appmenu"

      # Flexible Spacer
      "org.kde.plasma.panelspacer"

      # Application Launcher (Kickoff)
      {
        kickoff = {
          icon = null; # use default icon (KDE)
          label = null; # no text next to icon
          sortAlphabetically = false; # manual sorting
          favoritesDisplayMode = "grid";
          applicationsDisplayMode = "list";
          showButtonsFor = "power";
          showActionButtonCaptions = false; # no captions for shutdown,sleep,etc buttons
          popupWidth = 950;
          popupHeight = 625;
        };
      }

      # 4px Fixed Spacer
      {
        name = "org.kde.plasma.panelspacer";
        config.General = {
          expanding = false;
          length = 4;
        };
      }

      # Virtual Desktop Pager
      {
        pager = {
          general = {
            displayedText = "desktopNumber";
            showWindowOutlines = false;
            selectingCurrentVirtualDesktop = "doNothing";
          };
        };
      }

      # Flexible Spacer
      "org.kde.plasma.panelspacer"

      # Margins Separator (start small tray icons)
      "org.kde.plasma.marginsseparator"

      # Color Picker
      "org.kde.plasma.colorpicker"

      # 6px Fixed Spacer
      {
        name = "org.kde.plasma.panelspacer";
        config.General = {
          expanding = false;
          length = 6;
        };
      }

      # System Tray
      {
        systemTray = {
          icons = {
            scaleToFit = false;
            spacing = "medium";
          };
          items = { # not specified = show when relevant
            hidden = [ # always hide
              "Yakuake"
              "chrome_status_icon_1"
              "spotify-client"
              "org.kde.plasma.brightness"
              "org.kde.plasma.battery"
            ];
            shown = []; # always show
          };
        };
      }

      # 6px Fixed Spacer
      {
        name = "org.kde.plasma.panelspacer";
        config.General = {
          expanding = false;
          length = 6;
        };
      }

      # Digital Clock
      {
        digitalClock = {
          date = {
            enable = true;
            format = {
              custom = "ddd dd/MM"; # Thu 29/01
            };
            position = "adaptive";
          };
          time = {
            format = "default";
            showSeconds = "onlyInTooltip";
          };
          timeZone = {
            selected = [
              "Local"
              "Europe/London"
            ];
            lastSelected = "Local";
            format = "code";
            alwaysShow = false; # hide when time zone is same as system
            changeOnScroll = true;
          };
          calendar = {
            firstDayOfWeek = "monday";
            plugins = [ "holidaysevents" ];
          };
          font = {
            family = "JetBrains Mono";
            weight = 400;
            size = 10;
          };
        };
      }

      # Margins Separator (end small tray icons)
      "org.kde.plasma.marginsseparator"
    ];
  }

  # ══════════════════════════════════════════════════════════════════
  # Secondary monitor panel (screen 1)
  # ══════════════════════════════════════════════════════════════════
  {
    screen = 1;
    location = "top";
    alignment = "center"; # doesnt have any effect when full width
    height = 25; # must be odd for window title and global menu text to line up
    opacity = "adaptive";
    hiding = null; # always show by default (null is default)
    # full width (null is defaults)
    offset = null;
    minLength = null;
    maxLength = null;
    lengthMode = null;

    # widgets on the panel - left to right
    widgets = [
      # Icons-only Task Manager (raw config as some things above weren't working)
      {
        name = "org.kde.plasma.icontasks";
        config.General = {
          forceStripes = false;
          groupingStrategy = 1;           # byProgramName
          highlightWindows = true;
          iconSpacing = 3;                # large
          indicateAudioStreams = true;
          launchers = "";
          middleClickAction = 2;          # newInstance
          minimizeActiveTaskOnClick = true;
          reverseMode = false;
          showOnlyCurrentActivity = true;
          showOnlyCurrentDesktop = true;
          showOnlyCurrentScreen = true;
          showToolTips = true;
          sortingStrategy = 6;            # <-- changed from 5
          unhideOnAttention = true;
          wheelEnabled = true;
          wheelSkipMinimized = true;
        };
      }

      # Window Title (third-party widget - needs raw config)
      {
        name = "org.kde.windowtitle";
        config = {
          Appearance = {
            activityIcon = false;
            altTxt = "";
            elidePos = 2;
            fillThickness = true;
            fixedLength = 300;
            fontSize = 15;
            isBold = true;
            lastSpace = 6;
            lengthKind = 2;
            midSpace = 16;
            noIcon = true;
            txt = "%a";
            visible = false;
          };
          Substitutions = {
            subsMatchApp = ''"Telegram Desktop","Gimp-.*","soffice.bin","Spotify.*","Plasma Desktop Workspace","java","bolt"'';
            subsMatchTitle = ''".*",".*",".*",".*",".*",".*",".*"'';
            subsReplace = ''"Telegram","Gimp","LibreOffice","Spotify","Desktop Workspace","Java - %w","Bolt Launcher"'';
          };
        };
      }

      # Global Menu (App Menu)
      "org.kde.plasma.appmenu"

      # Flexible Spacer
      "org.kde.plasma.panelspacer"

      # Application Launcher (Kickoff)
      {
        kickoff = {
          icon = null; # use default icon (KDE)
          label = null; # no text next to icon
          sortAlphabetically = false; # manual sorting
          favoritesDisplayMode = "grid";
          applicationsDisplayMode = "list";
          showButtonsFor = "power";
          showActionButtonCaptions = false; # no captions for shutdown,sleep,etc buttons
          popupWidth = 950;
          popupHeight = 625;
        };
      }

      # 4px Fixed Spacer
      {
        name = "org.kde.plasma.panelspacer";
        config.General = {
          expanding = false;
          length = 4;
        };
      }

      # Virtual Desktop Pager
      {
        pager = {
          general = {
            displayedText = "desktopNumber";
            showWindowOutlines = true;
            selectingCurrentVirtualDesktop = "doNothing";
          };
        };
      }

      # Flexible Spacer
      "org.kde.plasma.panelspacer"

      # Margins Separator (start small tray icons)
      "org.kde.plasma.marginsseparator"

      # System Tray
      {
        systemTray = {
          icons = {
            scaleToFit = false;
            spacing = "medium";
          };
          items = { # not specified = show when relevant
            hidden = [ # always hide
              "Yakuake"
              "chrome_status_icon_1"
              "spotify-client"
              "org.kde.plasma.brightness"
              "org.kde.plasma.battery"
            ];
            shown = []; # always show
          };
        };
      }

      # 6px Fixed Spacer
      {
        name = "org.kde.plasma.panelspacer";
        config.General = {
          expanding = false;
          length = 6;
        };
      }

      # Digital Clock
      {
        digitalClock = {
          date = {
            enable = true;
            format = {
              custom = "ddd dd/MM"; # Thu 29/01
            };
            position = "adaptive";
          };
          time = {
            format = "default";
            showSeconds = "onlyInTooltip";
          };
          timeZone = {
            selected = [
              "Local"
              "Europe/London"
            ];
            lastSelected = "Local";
            format = "code";
            alwaysShow = false; # hide when time zone is same as system
            changeOnScroll = true;
          };
          calendar = {
            firstDayOfWeek = "monday";
            plugins = [ "holidaysevents" ];
          };
          font = {
            family = "JetBrains Mono";
            weight = 400;
            size = 10;
          };
        };
      }

      # Margins Separator (end small tray icons)
      "org.kde.plasma.marginsseparator"
    ];
  }
]
