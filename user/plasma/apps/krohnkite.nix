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
    # layouts
    kwin.KrohnkiteNextLayout = "Meta+\\";
    kwin.KrohnkitePreviousLayout = "Meta+|";
    kwin.KrohnkiteMonocleLayout = [];
    kwin.KrohnkiteBTreeLayout = [];
    kwin.KrohnkiteColumnsLayout = [];
    kwin.KrohnkiteFloatingLayout = [];
    kwin.KrohnkiteQuarterLayout = [];
    kwin.KrohnkiteSpiralLayout = [];
    kwin.KrohnkiteSpreadLayout = [];
    kwin.KrohnkiteStackedLayout = [];
    kwin.KrohnkiteStairLayout = [];
    kwin.KrohnkiteTileLayout = [];
    kwin.KrohnkiteTreeColumnLayout = [];
    # rotate
    kwin.KrohnkiteRotate = "Meta+Alt+o";
    kwin.KrohnkiteRotatePart = "Meta+Alt+p";
    # increase/decrease (number of master nodes)
    kwin.KrohnkiteIncrease = "Meta+Alt+i";
    kwin.KrohnkiteDecrease = "Meta+Alt+u";
    # TODO:
    # kwin.KrohnkitetoggleDock = [];
  };

  configFile = {
    # ENABLE KROHNKITE
    # Equivilent of: System Settings > KWin Scripts > Krohnkite > check the box > apply)
    kwinrc.Plugins.krohnkiteEnabled = true;

    # window rules
    # kwinrc.Script-krohnkite.ignoreClass = "krunner,yakuake,spectacle,kded5,xwaylandvideobridge,plasmashell,ksplashqml,org.kde.plasmashell,org.kde.polkit-kde-authentication-agent-1,org.kde.kruler,kruler,kwin_wayland,ksmserver-logout-greeter,org.kde.yakuake,yakuake";
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

    # kwinrc.Script-krohnkite.floatingClass = "BoltLauncher,org.prismlauncher.PrismLauncher,org.kde.yakuake,synergy,ord.freedesktop.impl.portal.desktop.kde,systemsettings,kcm_kwinrules";
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
    ];

    # kwinrc.Script-krohnkite.floatingTitle = "Input Capture Requested,Remote control requested,RuneLite Launcher";
    # Start windows with this title as floating (but still manage them)
    kwinrc.Script-krohnkite.floatingTitle = builtins.concatStringsSep "," [
      "Input Capture Requested"
      "Remote control requested"
      "RuneLite Launcher"
    ];

    # layout order (0 = disabled)
    kwinrc.Script-krohnkite.tiledWindowsLayer = 1;
    kwinrc.Script-krohnkite.columnsLayoutOrder = 2;
    kwinrc.Script-krohnkite.threeColumnLayoutOrder = 3;
    kwinrc.Script-krohnkite.quarterLayoutOrder = 4;
    kwinrc.Script-krohnkite.binaryTreeLayoutOrder = 0;
    kwinrc.Script-krohnkite.cascadeLayoutOrder = 0;
    kwinrc.Script-krohnkite.floatingLayoutOrder = 0;
    kwinrc.Script-krohnkite.monocleLayoutOrder = 0;
    kwinrc.Script-krohnkite.spiralLayoutOrder = 0;
    kwinrc.Script-krohnkite.spreadLayoutOrder = 0;
    kwinrc.Script-krohnkite.stackedLayoutOrder = 0;
    kwinrc.Script-krohnkite.stairLayoutOrder = 0;
  };
}
