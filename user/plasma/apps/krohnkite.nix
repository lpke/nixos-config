# These settings are imported and merged into the rest of the plasma-manager config

{
  shortcuts = {
    # focus - disabled as it's handled natively
    kwin.KrohnkiteFocusDown = [];
    kwin.KrohnkiteFocusLeft = [];
    kwin.KrohnkiteFocusRight = [];
    kwin.KrohnkiteFocusUp = [];
    kwin.KrohnkiteFocusNext = [];
    kwin.KrohnkiteFocusPrev = [];
    # move
    kwin.KrohnkiteSetMaster = "Meta+Return"; # move window to master node
    kwin.KrohnkiteShiftDown = "Meta+Down";
    kwin.KrohnkiteShiftLeft = "Meta+Left";
    kwin.KrohnkiteShiftRight = "Meta+Right";
    kwin.KrohnkiteShiftUp = "Meta+Up";
    # resize
    kwin.KrohnkiteGrowHeight = "Meta+Alt+j";
    kwin.KrohnkitegrowWidth = "Meta+Alt+l";
    kwin.KrohnkiteShrinkHeight = "Meta+Alt+k";
    kwin.KrohnkiteShrinkWidth = "Meta+Alt+h";
    # floating
    kwin.KrohnkiteToggleFloat = "Meta+F";
    kwin.KrohnkiteFloatAll = "Meta+Shift+F";
    # dock (pinned to left/right/top/bottom, outside of layout)
    kwin.KrohnkitetoggleDock = "Meta+Alt+D";
    # layouts
    kwin.KrohnkiteNextLayout = "Meta+Alt+."; # default: Meta+\
    kwin.KrohnkitePreviousLayout = "Meta+Alt+,"; # default: Meta+|
    kwin.KrohnkiteTreeColumnLayout = "Meta+Alt+C";
    kwin.KrohnkiteMonocleLayout = "Meta+Alt+S"; # fullscreen all"
    kwin.KrohnkiteFloatingLayout = "Meta+Alt+F"; # "float all"
    kwin.KrohnkiteBTreeLayout = [];
    kwin.KrohnkiteColumnsLayout = [];
    kwin.KrohnkiteQuarterLayout = [];
    kwin.KrohnkiteSpiralLayout = [];
    kwin.KrohnkiteSpreadLayout = [];
    kwin.KrohnkiteStackedLayout = [];
    kwin.KrohnkiteStairLayout = [];
    kwin.KrohnkiteTileLayout = [];
    # rotate
    kwin.KrohnkiteRotate = "Meta+Alt+o";
    kwin.KrohnkiteRotatePart = "Meta+Alt+p";
    # increase/decrease (number of master nodes)
    kwin.KrohnkiteIncrease = "Meta+Alt+i";
    kwin.KrohnkiteDecrease = "Meta+Alt+u";
  };

  configFile = {
    # ENABLE KROHNKITE
    # Equivilent of: System Settings > KWin Scripts > Krohnkite > check the box > apply)
    kwinrc.Plugins.krohnkiteEnabled = true;

    # WINDOW RULES
    # Fully ignore windows with this class
    kwinrc.Script-krohnkite.ignoreClass = builtins.concatStringsSep "," [
      "krunner"
      "yakuake"
      "spectacle"
      "kded5"
      "xwaylandvideobridge"
      "plasmashell"
      "ksplashqml"
      "org.kde.plasmashell"
      "org.kde.polkit-kde-authentication-agent-1"
      "org.kde.kruler"
      "kruler"
      "kwin_wayland"
      "ksmserver-logout-greeter"
      "org.kde.yakuake"
      "yakuake"
    ];

    # Start windows with this class as floating (but still manage them)
    kwinrc.Script-krohnkite.floatingClass = builtins.concatStringsSep "," [
      "BoltLauncher"
      "org.prismlauncher.PrismLauncher"
      "org.kde.yakuake"
      "synergy"
      "ord.freedesktop.impl.portal.desktop.kde"
      "systemsettings"
      "kcm_kwinrules"
      "VirtualBox"
      "VirtualBox Manager"
      "org.kde.plasma-systemmonitor"
      "org.kde.plasma.emojier"
      "kcm_krunnersettings"
      "org.kde.kmenuedit"
    ];

    # Start windows with this title as floating (but still manage them)
    kwinrc.Script-krohnkite.floatingTitle = builtins.concatStringsSep "," [
      "Input Capture Requested"
      "Remote control requested"
      "RuneLite Launcher"
    ];

    # layout order (0 = disabled completely)
    kwinrc.Script-krohnkite.threeColumnLayoutOrder = 1; # also accessed with direct shortcut
    kwinrc.Script-krohnkite.columnsLayoutOrder = 2;
    kwinrc.Script-krohnkite.tileLayoutOrder = 3;
    kwinrc.Script-krohnkite.monocleLayoutOrder = 4; # also accessed with direct shortcut
    kwinrc.Script-krohnkite.floatingLayoutOrder = 5; # also accessed with direct shortcut
    # hot garbage layouts
    kwinrc.Script-krohnkite.quarterLayoutOrder = 0;
    kwinrc.Script-krohnkite.spiralLayoutOrder = 0;
    kwinrc.Script-krohnkite.binaryTreeLayoutOrder = 0;
    kwinrc.Script-krohnkite.cascadeLayoutOrder = 0;
    kwinrc.Script-krohnkite.spreadLayoutOrder = 0;
    kwinrc.Script-krohnkite.stackedLayoutOrder = 0;
    kwinrc.Script-krohnkite.stairLayoutOrder = 0;
  };
}
