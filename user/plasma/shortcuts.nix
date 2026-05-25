{ lib }:

let
  krohnkite = (import ./apps/krohnkite.nix).shortcuts;
  konsoleYakuake = (import ./apps/konsole-yakuake.nix { inherit lib; }).shortcuts;

in lib.foldl' lib.recursiveUpdate {} [
    # merged-in shortcuts:
    krohnkite
    konsoleYakuake
    # all other shortcuts:
    {
      # ====== DISABLED ======
      plasmashell."activate application launcher" = []; # default/special: Meta, Alt+F1
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
      "KDE Keyboard Layout Switcher"."Switch to Last-Used Keyboard Layout" = []; # default: Meta+Alt+L
      "KDE Keyboard Layout Switcher"."Switch to Next Keyboard Layout" = []; # default: Meta+Alt+K
      kwin."Window to Next Screen" = []; # default: Meta+Shift+Right
      kwin."Window to Previous Screen" = []; # default: Meta+Shift+Left
      kwin.disableInputCapture = []; # default: Meta+Shift+Esc
      "services/org.kde.kscreen.desktop".ShowOSD = ["Display"]; # Switch display. default: Display, Meta+P
      # power
      org_kde_powerdevil.Hibernate = []; # default: "Hibernate"
      org_kde_powerdevil.PowerDown = []; # default: "Power Down"
      org_kde_powerdevil.PowerOff = []; # default: "Power Off"
      org_kde_powerdevil.Sleep = []; # default: "Sleep"
      org_kde_powerdevil."Turn Off Screen" = [];
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

      # ====== ADDED (no default) ======
      # launching
      "services/Alacritty.desktop"._launch = "Meta+M";
      "services/vivaldi-stable.desktop"._launch = [];
      "services/helium.desktop"._launch = "Meta+N";
      # window misc
      kwin."Window No Border" = "Meta+D";
      kwin."Window Fullscreen" = "Meta+A"; # real fullscreen (covers panel)
      # window move to another screen (monitor)
      kwin."Window One Screen Up" = "Meta+Ctrl+Alt+Shift+Up";
      kwin."Window One Screen Down" = "Meta+Ctrl+Alt+Shift+Down";
      kwin."Window One Screen to the Left" = "Meta+Ctrl+Alt+Shift+Left";
      kwin."Window One Screen to the Right" = "Meta+Ctrl+Alt+Shift+Right";
      # window growing (native)
      kwin."Window Grow Vertical" = "Meta+Alt+V";
      kwin."Window Grow Horizontal" = "Meta+Alt+B";
      # window maximizing (native)
      kwin."Window Maximize Vertical" = "Meta+Alt+Shift+V";
      kwin."Window Maximize Horizontal" = "Meta+Alt+Shift+B";
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
      # activities
      plasmashell."manage activities" = "Meta+Q";
      # window misc
      kwin."Window Maximize" = "Meta+S"; # fake fullscreen. default: Meta+PgUp
      # alt-tabbing
      kwin."Walk Through Windows of Current Application" = "Meta+Shift+Tab"; # default: meta+`, alt+`
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
      # alt-tabbing
      kwin."Walk Through Windows" = "Meta+Tab"; # default: alt+tab, meta+tab
      # exploded views
      kwin.Overview = "Meta+W";
      kwin."Grid View" = "Meta+G";
      # desktop switching
      kwin."Switch One Desktop Down" = "Meta+Ctrl+Down";
      kwin."Switch One Desktop Up" = "Meta+Ctrl+Up";
      kwin."Switch One Desktop to the Left" = "Meta+Ctrl+Left";
      kwin."Switch One Desktop to the Right" = "Meta+Ctrl+Right";
      # zooming
      kwin.view_actual_size = "Meta+0";
      kwin.view_zoom_in = ["Meta++" "Meta+="];
      kwin.view_zoom_out = "Meta+-";

      # ====== ADDED TO DEFAULTS (default on left) ======
      # window killing
      kwin."Kill Window" = ["Meta+Ctrl+Esc" "Meta+Ctrl+Del"]; # trigger window kill cursor. default: Meta+Ctrl+Esc
    }]
