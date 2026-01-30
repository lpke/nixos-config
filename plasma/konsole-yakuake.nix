# These settings are imported and merged into the rest of the plasma-manager config
{ lib }:

let
  rosePineColorscheme = "luke_rose-pine";
  rosePineBreezeColorscheme = "luke_rose-pine-breeze";

  konsoleProfile = "luke_konsole";
  konsoleColorscheme = rosePineBreezeColorscheme;
  yakuakeProfile = "luke_yakuake";
  yakuakeColorscheme = rosePineBreezeColorscheme;

  sharedProfile = {
    General = {
      Parent = "FALLBACK/";
      ShowTerminalSizeHint = false;
      TerminalMargin = 6;
    };
    Appearance = {
      BoldIntense = true;
      BorderWhenActive = false;
    };
    Scrolling = {
      HighlightScrolledLines = false;
      HistoryMode = 2;
      ScrollBarPosition = 2;
    };
  };

  sharedColorscheme = {
    General = {
      Anchor = "0.5,0.5";
      Blur = false;
      ColorRandomization = false;
      FillStyle = "Tile";
      Opacity = 1;
      Wallpaper = "";
      WallpaperFlipType = "NoFlip";
      WallpaperOpacity = 1;
    };
  };

  colors = {
    # Based on Rose Pine, slightly tweaked: https://rosepinetheme.com/palette/ingredients/
    # Colors in Konsole GUI settings are +1 from these (un-zero indexed)
    # Format: <terminal_color> (<rose_pine_color>)
    rosePine = {
      # Foreground (text)
      Foreground.Color = "224,222,236";
      ForegroundFaint.Color = "224,222,236";
      ForegroundIntense.Color = "224,222,236";
      # Black (base)
      Color0.Color = "38,35,58";
      Color0Faint.Color = "38,35,58";
      Color0Intense.Color = "110,106,134"; # Bright Black (overlay)
      # Red (love)
      Color1.Color = "242,86,111";
      Color1Faint.Color = "242,86,111";
      Color1Intense.Color = "242,86,111";
      # Green (pine, brightened)
      Color2.Color = "58,138,170";
      Color2Faint.Color = "58,138,170";
      Color2Intense.Color = "47,153,138"; # Bright Green ("growth")
      # Yellow (gold)
      Color3.Color = "246,193,119";
      Color3Faint.Color = "246,193,119";
      Color3Intense.Color = "246,193,119";
      # Blue (foam)
      Color4.Color = "156,207,216";
      Color4Faint.Color = "156,207,216";
      Color4Intense.Color = "156,207,216";
      # Magenta (iris)
      Color5.Color = "196,167,231";
      Color5Faint.Color = "196,167,231";
      Color5Intense.Color = "196,167,231";
      # Cyan (rose)
      Color6.Color = "235,188,186";
      Color6Faint.Color = "235,188,186";
      Color6Intense.Color = "235,188,186";
      # White (text)
      Color7.Color = "224,222,236";
      Color7Faint.Color = "224,222,236";
      Color7Intense.Color = "224,222,236";
    };
  };

  bgColors = {
    rosePine = {
      Background.Color = "25,23,36";
      BackgroundFaint.Color = "25,23,36";
      BackgroundIntense.Color = "25,23,36";
    };
    breezeDark = {
      Background.Color = "32,35,38";
      BackgroundFaint.Color = "32,35,38";
      BackgroundIntense.Color = "32,35,38";
    };
  };

in
  {
  shortcuts = {
    # Yakuake Shortcuts
    yakuake.toggle-window-state = "Print"; # default: F12
  };

  configFile = {
    # Konsole Settings
    "konsolerc" = {
      General.ConfigVersion = 1;
      "Desktop Entry" = {
        DefaultProfile = "${konsoleProfile}.profile";
        MenuBar = "Disabled";
      };
      MainWindow.ToolBarsMovable = "Enabled";
      "Notification Messages".CloseAllTabs = true;
      TabBar.ExpandTabWidth = true;
      UiSettings.ColorScheme = "";
    };

    # Yakuake Settings
    "yakuakerc" = {
      "Desktop Entry" = {
        DefaultProfile = "${yakuakeProfile}.profile";
      };
      Animation.Frames = 16;
      Dialogs.FirstRun = false;
      Window = {
        Height = 60;
        KeepOpen = false;
        ShowTabBar = false;
        ShowTitleBar = false;
        Width = 60;
      };
    };
  };

  dataFile = {
    # Konsole/Yakuake Profiles
    "konsole/${konsoleProfile}.profile" = lib.recursiveUpdate sharedProfile {
      General = {
        Name = konsoleProfile;
        Command = ''/run/current-system/sw/bin/zsh -c "command -v tmux >/dev/null && { (tmux ls -F '#{session_name}:#{?session_attached,1,0}' 2>/dev/null | grep -q '^main:0$' && tmux attach -t main) || tmux attach -t $(tmux ls -F '#{session_name}:#{?session_attached,attached,detached}' 2>/dev/null | grep ':detached$' | head -1 | cut -d: -f1) 2>/dev/null || tmux new-session; }; exec zsh || exec zsh"'';
        Icon = "akonadiconsole-symbolic";
      };
      Appearance = {
        ColorScheme = konsoleColorscheme;
      };
    };
    "konsole/${yakuakeProfile}.profile" = lib.recursiveUpdate sharedProfile {
      General = {
        Name = yakuakeProfile;
        Command = ''/run/current-system/sw/bin/zsh -c "command -v tmux >/dev/null && tmux new-session -A -s yakuake; exec zsh || exec zsh"'';
        Icon = "yakuake";
        TerminalCenter = false;
      };
      Appearance = {
        ColorScheme = yakuakeColorscheme;
      };
    };

    # Colorschemes
    "konsole/${rosePineColorscheme}.colorscheme" = lib.recursiveUpdate sharedColorscheme
      (colors.rosePine // bgColors.rosePine // {
        General = {
          Description = rosePineColorscheme;
        };
      });
    "konsole/${rosePineBreezeColorscheme}.colorscheme" = lib.recursiveUpdate sharedColorscheme
      (colors.rosePine // bgColors.breezeDark // {
        General = {
          Description = rosePineBreezeColorscheme;
        };
      });
  };
}
