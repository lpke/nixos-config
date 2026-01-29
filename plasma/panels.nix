# Overview: https://thedocumentation.org/plasma-manager/configuration/panels/
# Widget config: https://github.com/nix-community/plasma-manager/tree/trunk/modules/widgets
# Tip: Go to source code module for something, and ask AI to parse and present available options

let
  # ══════════════════════════════════════════════════════════════════
  # Widget definitions
  # ══════════════════════════════════════════════════════════════════

  spacerFlex = "org.kde.plasma.panelspacer";

  spacer4px = {
    name = "org.kde.plasma.panelspacer";
    config.General = {
      expanding = false;
      length = 4;
    };
  };

  spacer6px = {
    name = "org.kde.plasma.panelspacer";
    config.General = {
      expanding = false;
      length = 6;
    };
  };

  marginsSeparator = "org.kde.plasma.marginsseparator";

  activeApps = {
    name = "org.kde.plasma.icontasks";
    config.General = {
      forceStripes = false;
      groupingStrategy = 1; # by program name
      highlightWindows = true;
      iconSpacing = 3; # large
      indicateAudioStreams = true;
      launchers = "";
      middleClickAction = 2; # open new instance
      minimizeActiveTaskOnClick = true;
      reverseMode = false;
      showOnlyCurrentActivity = true;
      showOnlyCurrentDesktop = true;
      showOnlyCurrentScreen = true;
      showToolTips = true;
      sortingStrategy = 6; # by horizontal window position
      unhideOnAttention = true;
      wheelEnabled = "TaskOnly"; # scroll through apps windows
      wheelSkipMinimized = true; # skip minimised windows when scrolling
    };
  };

  windowTitle = {
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
  };

  globalMenu = "org.kde.plasma.appmenu";

  appLauncher = {
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
  };

  mkDesktopPager = showWindowOutlines: {
    pager = {
      general = {
        inherit showWindowOutlines;
        displayedText = "desktopNumber";
        selectingCurrentVirtualDesktop = "doNothing";
      };
    };
  };

  colorPicker = [
    "org.kde.plasma.colorpicker"
    spacer6px
  ];

  systemTray = {
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
  };

  digitalClock = {
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
  };

  # ══════════════════════════════════════════════════════════════════
  # Panel builder factory function
  # ══════════════════════════════════════════════════════════════════
  mkPanel = { screen, showWindowOutlines, includeColorPicker }: {
    inherit screen;
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
      activeApps # left
      windowTitle
      globalMenu
      spacerFlex
      appLauncher # middle
      spacer4px
      (mkDesktopPager showWindowOutlines)
      spacerFlex
      marginsSeparator # right - start small tray icons
    ]
      ++ (if includeColorPicker then colorPicker else [])
      ++ [
        systemTray
        spacer6px
        digitalClock
        marginsSeparator # end small tray icons
      ];
  };

in [
  # ══════════════════════════════════════════════════════════════════
  # Panels (built with factory function)
  # ══════════════════════════════════════════════════════════════════

  # primary monitor
  (mkPanel {
    screen = 0;
    showWindowOutlines = false;
    includeColorPicker = true;
  })

  (mkPanel {
    screen = 1;
    showWindowOutlines = true;
    includeColorPicker = false;
  })
]
