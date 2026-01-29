{
  # ====== DISABLED ======
  org_kde_powerdevil.powerProfile = ["Battery"]; # disabled default Meta+B
  plasmashell.cycle-panels = []; # default: Meta+Alt+p
  kaccess."Toggle Screen Reader On and Off" = [];
  kwin."Activate Window Demanding Attention" = [];
  plasmashell."activate task manager entry 1" = []; # default: Meta+<num>
  plasmashell."activate task manager entry 2" = [];
  plasmashell."activate task manager entry 3" = [];
  plasmashell."activate task manager entry 4" = [];
  plasmashell."activate task manager entry 5" = [];
  plasmashell."activate task manager entry 6" = [];
  plasmashell."activate task manager entry 7" = [];
  plasmashell."activate task manager entry 8" = [];
  plasmashell."activate task manager entry 9" = [];
  plasmashell."activate task manager entry 10" = [];
  kwin.Expose = []; # variations on "overview"
  kwin.ExposeAll = [];
  kwin.ExposeClass = [];
  kwin.ExposeClassCurrentDesktop = [];
  # window tiling (handle with Krohnkite)
  kwin."Edit Tiles" = [];
  kwin."Window Quick Tile Bottom" = [];
  kwin."Window Quick Tile Bottom Left" = [];
  kwin."Window Quick Tile Bottom Right" = [];
  kwin."Window Quick Tile Left" = [];
  kwin."Window Quick Tile Right" = [];
  kwin."Window Quick Tile Top" = [];
  kwin."Window Quick Tile Top Left" = [];
  kwin."Window Quick Tile Top Right" = [];

  # ====== KROHNKITE ======
  kwin.KrohnkiteSetMaster = "Meta+Return";
  # move
  kwin.KrohnkiteShiftDown = "Meta+Down";
  kwin.KrohnkiteShiftLeft = "Meta+Left";
  kwin.KrohnkiteShiftRight = "Meta+Right";
  kwin.KrohnkiteShiftUp = "Meta+Up";
  # resize
  kwin.KrohnkiteGrowHeight = "Meta+Alt+Down";
  kwin.KrohnkitegrowWidth = "Meta+Alt+Right";
  kwin.KrohnkiteShrinkHeight = "Meta+Alt+Up";
  kwin.KrohnkiteShrinkWidth = "Meta+Alt+Left";
  # floating
  kwin.KrohnkiteToggleFloat = "Meta+F";
  kwin.KrohnkiteFloatAll = "Meta+Shift+F";
  # layouts
  kwin.KrohnkiteMonocleLayout = [];
  # rotate
  kwin.KrohnkiteRotate = "Meta+Alt+o";
  kwin.KrohnkiteRotatePart = "Meta+Alt+p";
  # increase/decrease
  kwin.KrohnkiteIncrease = "Meta+Alt+i";
  kwin.KrohnkiteDecrease = "Meta+Alt+u";
  # kwin.KrohnkiteBTreeLayout = [ ];
  # kwin.KrohnkiteColumnsLayout = [ ];
  # kwin.KrohnkiteFloatingLayout = [ ];
  # kwin.KrohnkiteFocusDown = [ ];
  # kwin.KrohnkiteFocusLeft = [ ];
  # kwin.KrohnkiteFocusNext = [ ];
  # kwin.KrohnkiteFocusPrev = "Meta+\\";
  # kwin.KrohnkiteFocusRight = [ ];
  # kwin.KrohnkiteFocusUp = [ ];
  # kwin.KrohnkiteNextLayout = "Meta+\\\\,none";
  # kwin.KrohnkitePreviousLayout = "Meta+|";
  # kwin.KrohnkiteQuarterLayout = [ ];
  # kwin.KrohnkiteSpiralLayout = [ ];
  # kwin.KrohnkiteSpreadLayout = [ ];
  # kwin.KrohnkiteStackedLayout = [ ];
  # kwin.KrohnkiteStairLayout = [ ];
  # kwin.KrohnkiteTileLayout = [ ];
  # kwin.KrohnkiteTreeColumnLayout = [ ];
  # kwin.KrohnkitetoggleDock = [ ];

  # ====== ADDED (no default) ======
  # launching
  "services/Alacritty.desktop"._launch = "Meta+M";
  "services/vivaldi-stable.desktop"._launch = "Meta+N";
  # window growing (native)
  kwin."Window Grow Horizontal" = "Meta+Alt+G";
  kwin."Window Grow Vertical" = "Meta+Alt+F";
  # window move to specific desktop
  kwin."Window to Desktop 1" = "Meta+Alt+1";
  kwin."Window to Desktop 2" = "Meta+Alt+2";
  kwin."Window to Desktop 3" = "Meta+Alt+3";
  kwin."Window to Desktop 4" = "Meta+Alt+4";
  kwin."Window to Desktop 5" = "Meta+Alt+5";
  kwin."Window to Desktop 6" = "Meta+Alt+6";
  kwin."Window to Desktop 7" = "Meta+Alt+7";
  kwin."Window to Desktop 8" = "Meta+Alt+8";
  kwin."Window to Desktop 9" = "Meta+Alt+9";
  kwin."Window to Desktop 10" = "Meta+Alt+0";
  kwin."Window to Desktop 11" = [];
  kwin."Window to Desktop 12" = [];
  kwin."Window to Desktop 13" = [];
  kwin."Window to Desktop 14" = [];
  kwin."Window to Desktop 15" = [];
  kwin."Window to Desktop 16" = [];
  kwin."Window to Desktop 17" = [];
  kwin."Window to Desktop 18" = [];
  kwin."Window to Desktop 19" = [];
  kwin."Window to Desktop 20" = [];

  # ====== CHANGED FROM DEFAULTS ======
  # launching
  "services/org.kde.krunner.desktop"._launch = ["Meta+Space" "Search"]; # default: Search, Alt+Space, Alt+F2
  "services/org.kde.spectacle.desktop"._launch = "Meta+Alt+Shift+S"; # default: Meta+Shift+s, Print (now yakuake)
  yakuake.toggle-window-state = "Print"; # default: F12
  # window misc
  kwin."Window Maximize" = "Meta+s"; # default: Meta+PgUp
  # window directional focusing
  kwin."Switch Window Down" = "Meta+j"; # default: Meta+Alt+<arrow>
  kwin."Switch Window Left" = "Meta+h";
  kwin."Switch Window Right" = "Meta+l";
  kwin."Switch Window Up" = "Meta+k";
  # desktop number switching
  kwin."Switch to Desktop 1" = "Meta+1"; # default: Ctrl+F<num> up to 4
  kwin."Switch to Desktop 2" = "Meta+2";
  kwin."Switch to Desktop 3" = "Meta+3";
  kwin."Switch to Desktop 4" = "Meta+4";
  kwin."Switch to Desktop 5" = "Meta+5";
  kwin."Switch to Desktop 6" = "Meta+6";
  kwin."Switch to Desktop 7" = "Meta+7";
  kwin."Switch to Desktop 8" = "Meta+8";
  kwin."Switch to Desktop 9" = "Meta+9";
  kwin."Switch to Desktop 10" = "Meta+0";
  kwin."Switch to Desktop 11" = [];
  kwin."Switch to Desktop 12" = [];
  kwin."Switch to Desktop 13" = [];
  kwin."Switch to Desktop 14" = [];
  kwin."Switch to Desktop 15" = [];
  kwin."Switch to Desktop 16" = [];
  kwin."Switch to Desktop 17" = [];
  kwin."Switch to Desktop 18" = [];
  kwin."Switch to Desktop 19" = [];
  kwin."Switch to Desktop 20" = [];
  # window killing
  kwin."Window Close" = ["Ctrl+Del" "Meta+/"]; # close currently focused window. default: Alt+F4

  # ====== KEPT DEFAULTS ======
  # launching
  plasmashell."activate application launcher" = ["Meta" "Alt+F1"];
  # exploded views
  kwin.Overview = "Meta+W";
  kwin."Grid View" = "Meta+G";
  # desktop switching
  kwin."Switch One Desktop Down" = "Meta+Ctrl+Down";
  kwin."Switch One Desktop Up" = "Meta+Ctrl+Up";
  kwin."Switch One Desktop to the Left" = "Meta+Ctrl+Left";
  kwin."Switch One Desktop to the Right" = "Meta+Ctrl+Right";

  # ====== ADDED TO DEFAULTS (default on left) ======
  # window killing
  kwin."Kill Window" = ["Meta+Ctrl+Esc" "Meta+Ctrl+Del"]; # trigger window kill cursor. default: Meta+Ctrl+Esc

  # ====== TODO ======
  # kwin."Switch to Next Desktop" = [];
  # kwin."Switch to Next Screen" = [];
  # kwin."Switch to Previous Desktop" = [];
  # kwin."Switch to Previous Screen" = [];
  # kwin."Switch to Screen 0" = [];
  # kwin."Switch to Screen 1" = [];
  # kwin."Switch to Screen 2" = [];
  # kwin."Switch to Screen 3" = [];
  # kwin."Switch to Screen 4" = [];
  # kwin."Switch to Screen 5" = [];
  # kwin."Switch to Screen 6" = [];
  # kwin."Switch to Screen 7" = [];
  # kwin."Switch to Screen Above" = [];
  # kwin."Switch to Screen Below" = [];
  # kwin."Switch to Screen to the Left" = [];
  # kwin."Switch to Screen to the Right" = [];
  # kwin."Toggle Night Color" = [];
  # kwin."Toggle Window Raise/Lower" = [];
  # kwin."Walk Through Windows" = "Meta+Tab";
  # kwin."Walk Through Windows (Reverse)" = [];
  # kwin."Walk Through Windows Alternative" = [];
  # kwin."Walk Through Windows Alternative (Reverse)" = [];
  # kwin."Walk Through Windows of Current Application" = "Meta+Shift+Tab";
  # kwin."Walk Through Windows of Current Application (Reverse)" = [];
  # kwin."Walk Through Windows of Current Application Alternative" = [];
  # kwin."Walk Through Windows of Current Application Alternative (Reverse)" = [];
  # kwin."Window Above Other Windows" = [];
  # kwin."Window Below Other Windows" = [];
  # kwin."Window Custom Quick Tile Bottom" = [];
  # kwin."Window Custom Quick Tile Left" = [];
  # kwin."Window Custom Quick Tile Right" = [];
  # kwin."Window Custom Quick Tile Top" = [];
  # kwin."Window Fullscreen" = [];
  # kwin."Window Lower" = [];
  # kwin."Window Maximize Horizontal" = [];
  # kwin."Window Maximize Vertical" = [];
  # kwin."Window Minimize" = "Meta+PgDown";
  # kwin."Window Move" = [];
  # kwin."Window Move Center" = [];
  # kwin."Window No Border" = "Meta+D";
  # kwin."Window On All Desktops" = [];
  # kwin."Window One Desktop Down" = "Meta+Ctrl+Shift+Down";
  # kwin."Window One Desktop Up" = "Meta+Ctrl+Shift+Up";
  # kwin."Window One Desktop to the Left" = "Meta+Ctrl+Shift+Left";
  # kwin."Window One Desktop to the Right" = "Meta+Ctrl+Shift+Right";
  # kwin."Window One Screen Down" = [];
  # kwin."Window One Screen Up" = [];
  # kwin."Window One Screen to the Left" = [];
  # kwin."Window One Screen to the Right" = [];
  # kwin."Window Operations Menu" = "Alt+F3";
  # kwin."Window Pack Down" = [];
  # kwin."Window Pack Left" = [];
  # kwin."Window Pack Right" = [];
  # kwin."Window Pack Up" = [];
  # kwin."Window Raise" = [];
  # kwin."Window Resize" = [];
  # kwin."Window Shrink Horizontal" = [];
  # kwin."Window Shrink Vertical" = [];
  # kwin."Window to Next Desktop" = [];
  # kwin."Window to Next Screen" = "Meta+Shift+Right";
  # kwin."Window to Previous Desktop" = [];
  # kwin."Window to Previous Screen" = "Meta+Shift+Left";
  # kwin."Window to Screen 0" = [];
  # kwin."Window to Screen 1" = [];
  # kwin."Window to Screen 2" = [];
  # kwin."Window to Screen 3" = [];
  # kwin."Window to Screen 4" = [];
  # kwin."Window to Screen 5" = [];
  # kwin."Window to Screen 6" = [];
  # kwin."Window to Screen 7" = [];
  # kwin.disableInputCapture = "Meta+Shift+Esc";
  # kwin.view_actual_size = "Meta+0";
  # kwin.view_zoom_in = ["Meta++" "Meta+="];
  # kwin.view_zoom_out = "Meta+-";
  # mediacontrol.mediavolumedown = [];
  # mediacontrol.mediavolumeup = [];
  # mediacontrol.nextmedia = "Media Next";
  # mediacontrol.pausemedia = "Media Pause";
  # mediacontrol.playmedia = [];
  # mediacontrol.playpausemedia = "Media Play";
  # mediacontrol.previousmedia = "Media Previous";
  # mediacontrol.stopmedia = "Media Stop";
  # org_kde_powerdevil."Decrease Keyboard Brightness" = "Keyboard Brightness Down";
  # org_kde_powerdevil."Decrease Screen Brightness" = "Monitor Brightness Down";
  # org_kde_powerdevil."Decrease Screen Brightness Small" = "Shift+Monitor Brightness Down";
  # org_kde_powerdevil.Hibernate = "Hibernate";
  # org_kde_powerdevil."Increase Keyboard Brightness" = "Keyboard Brightness Up";
  # org_kde_powerdevil."Increase Screen Brightness" = "Monitor Brightness Up";
  # org_kde_powerdevil."Increase Screen Brightness Small" = "Shift+Monitor Brightness Up";
  # org_kde_powerdevil.PowerDown = "Power Down";
  # org_kde_powerdevil.PowerOff = "Power Off";
  # org_kde_powerdevil.Sleep = "Sleep";
  # org_kde_powerdevil."Toggle Keyboard Backlight" = "Keyboard Light On/Off";
  # org_kde_powerdevil."Turn Off Screen" = [];
  # plasmashell."Slideshow Wallpaper Next Image" = [];
  #
  # plasmashell.clear-history = [];
  # plasmashell.clipboard_action = "Meta+Ctrl+X";
  # plasmashell.cycleNextAction = [];
  # plasmashell.cyclePrevAction = [];
  # plasmashell.edit_clipboard = [];
  # plasmashell."manage activities" = "Meta+Q";
  # plasmashell."next activity" = "Meta+A";
  # plasmashell."previous activity" = "Meta+Shift+A";
  # plasmashell.repeat_action = [];
  # plasmashell."show dashboard" = "Ctrl+F12";
  # plasmashell.show-barcode = [];
  # plasmashell.show-on-mouse-pos = "Meta+V";
  # plasmashell."switch to next activity" = [];
  # plasmashell."switch to previous activity" = [];
  # plasmashell."toggle do not disturb" = [];
  # "services/org.kde.konsole.desktop"._launch = [];
}
