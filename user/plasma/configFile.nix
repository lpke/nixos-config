{ lib }:

let
  krohnkite = (import ./apps/krohnkite.nix).configFile;
  konsoleYakuake = (import ./apps/konsole-yakuake.nix { inherit lib; }).configFile;
  windowDecorations = (import ./apps/windowDecorations.nix).configFile;
  kwin = (import ./apps/kwin.nix).configFile;
  spectacle = (import ./apps/spectacle.nix).configFile;
  krunner = (import ./apps/krunner.nix).configFile;
  fonts = (import ./apps/fonts.nix).configFile;

in lib.foldl' lib.recursiveUpdate {} [
    # merged-in configs:
    krohnkite
    konsoleYakuake
    windowDecorations
    kwin
    spectacle
    krunner
    fonts
    # all other configs:
    {
      plasma-localerc.Formats.LANG = "en_AU.UTF-8";

      ksmserverrc.General.loginMode = "restoreSavedSession";

      # screen locking
      kscreenlockerrc = {
        Greeter.WallpaperPlugin = "org.kde.haenau";
        Daemon = {
          Autolock = false;
          Timeout = 0;
        };
      };

      kdeglobals = {
        Shortcuts = {
          RenameFile = "Ctrl+Return";
          # DeleteWordForward = "";
        };

        General = {
          # default terminal
          TerminalApplication = "alacritty";
          TerminalService = "Alacritty.desktop";
        };

        KDE = {
          AnimationDurationFactor = 0.5;
          DndBehavior = "Ask"; # drag and drop behaviour: "MoveIfSameDevice" for moving without context menu
          ShowDeleteCommand = false; # show perma-delete context option in dolphin etc
        };

        # open/save/file select dialogs
        KFileDialog = {
          "Allow Expansion" = true; # allow dropdown expansion in details view
          "Automatically select filename extension" = true;
          "Breadcrumb Navigation" = true;
          "Decoration position" = 2;
          "Show Full Path" = false; # show GUI path unless clicked
          "Show Inline Previews" = true;
          "Show Preview" = false;
          "Show Speedbar" = true;
          "Show hidden files" = true;
          "Sort by" = "Name";
          "Sort directories first" = true;
          "Sort hidden files last" = false;
          "Sort reversed" = false;
          "View Style" = "DetailTree";
        };
      };

      # System Settings > Mouse
      kcminputrc = {
        # "xremap" takes over keyboard and mouse when xremap is running
        "Libinput/4660/22136/xremap" = {
          Enabled = true;
          PointerAcceleration = 0.000; # pointer speed (not technically acceleration)
          PointerAccelerationProfile = 1; # disable acceleration (this is the checkbox in the GUI)
          ScrollFactor = 1; # scroll speed
        };
        "Libinput/1133/16487/Logitech G903" = {
          Enabled = true;
          PointerAcceleration = 0.000;
          PointerAccelerationProfile = 1;
          ScrollFactor = 1;
        };
        "Libinput/12951/6505/ZSA Technology Labs Moonlander Mark I" = {
          Enabled = true;
          PointerAcceleration = 0.000;
          PointerAccelerationProfile = 1;
          ScrollFactor = 1;
        };
      };

      systemsettingsrc = {
        # open/save/file select dialog - static sidebar icons size
        "KFileDialog Settings" = {
          "Places Icons Auto-resize" = false;
          "Places Icons Static Size" = 22;
        };
      };

      # dolphin (file explorer)
      dolphinrc = {
        General = {
          ShowFullPath = true; # show path from root
          DoubleClickViewAction = "show_terminal_panel";
        };
        Search = {
          SearchTool = "Baloo";
        };
        # AKA preview panel
        InformationPanel = {
          showHovered = false; # only update previews on click
        };
        ContextMenu = {
          ShowCopyMoveMenu = true;
          # see more below under `kservicemenurc`
        };
        # open/save/file select dialog - static sidebar icons size
        "KFileDialog Settings" = {
          "Places Icons Auto-resize" = false;
          "Places Icons Static Size" = 22;
        };
        # allow previews for everything (including text files)
        PreviewSettings.Plugins = "appimagethumbnail,audiothumbnail,blenderthumbnail,comicbookthumbnail,cursorthumbnail,djvuthumbnail,ebookthumbnail,exrthumbnail,directorythumbnail,fontthumbnail,imagethumbnail,jpegthumbnail,kraorathumbnail,windowsexethumbnail,windowsimagethumbnail,mobithumbnail,opendocumentthumbnail,gsthumbnail,rawthumbnail,svgthumbnail,textthumbnail,ffmpegthumbs";
      };

      # other context menu options
      kservicemenurc = {
        Show = {
          # disabled
          slideshowfileitemaction = false; # gwenview: "Start a Slideshow"
          filelight = false; # filelight: "Show Disk Usage Statistics"
          # enabled
          compressfileitemaction = true;
          extractfileitemaction = true;
          forgetfileitemaction = true;
          installFont = true;
          kactivitymanagerd_fileitem_linking_plugin = true;
          kio-admin = true;
          makefileactions = true;
          mountisoaction = true;
          movetonewfolderitemaction = true;
          runInKonsole = true;
          setfoldericonitemaction = true;
          tagsfileitemaction = true;
          wallpaperfileitemaction = true;
        };
      };


      # moving/copying/deleting files/folders
      kiorc = {
        Confirmations = {
          ConfirmDelete = true; # perma-delete
          ConfirmTrash = false; # to trash
          ConfirmEmptyTrash = true;
        };
        "Executable scripts".behaviourOnLaunch = "alwaysAsk";
      };

      # baloo (search tool/indexer used by KDE)
      baloofilerc = {
        General = {
          "index hidden folders" = true;
        };
      };

      ktrashrc = {
        # size limit
        "\\/home\\/luke\\/.local\\/share\\/Trash".UseSizeLimit = true;
        "\\/home\\/luke\\/.local\\/share\\/Trash".Percent = 5; # max trash size as percent of disk
        "\\/home\\/luke\\/.local\\/share\\/Trash".LimitReachedAction = 1; # what happens if trash is full (size limit). 0 = warn, 1 = delete oldest, 2 = delete biggest
        # time limit
        "\\/home\\/luke\\/.local\\/share\\/Trash".UseTimeLimit = false;
        "\\/home\\/luke\\/.local\\/share\\/Trash".Days = 30; # auto-delete files older than X days (if `UseTimeLimit` is on)
      };

      plasmanotifyrc = {
        Notifications.PopupPosition = "BottomRight";
        # "Applications/vivaldi-stable".Seen = true;
      };

      katerc = {
        General = {
          # "Allow Tab Scrolling" = true;
          # "Auto Hide Tabs" = false;
          # "Close After Last" = false;
          # "Close documents with window" = true;
          # "Cycle To First Tab" = true;
          # "Days Meta Infos" = 30;
          # "Diagnostics Limit" = 12000;
          # "Diff Show Style" = 0;
          # "Elide Tab Text" = false;
          # "Enable Context ToolView" = false;
          # "Expand Tabs" = false;
          # "Icon size for left and right sidebar buttons" = 32;
          # "Last Session" = "chezmoi";
          # "Modified Notification" = false;
          # "Mouse back button action" = 0;
          # "Mouse forward button action" = 0;
          # "Open New Tab To The Right Of Current" = false;
          # "Output History Limit" = 100;
          # "Output With Date" = false;
          # "Quickopen Filter Mode" = 0;
          # "Quickopen List Mode" = true;
          # "Recent File List Entry Count" = 10;
          # "Restore Window Configuration" = true;
          # "SDI Mode" = false;
          # "Save Meta Infos" = true;
          # "Session Manager Sort Column" = 0;
          # "Session Manager Sort Order" = 0;
          # "Show Full Path in Title" = false;
          # "Show Menu Bar" = true;
          # "Show Status Bar" = true;
          # "Show Symbol In Navigation Bar" = true;
          # "Show Tab Bar" = true;
          # "Show Tabs Close Button" = true;
          # "Show Url Nav Bar" = true;
          # "Show output view for message type" = 1;
          # "Show text for left and right sidebar" = false;
          # "Show welcome view for new window" = false;
          # "Startup Session" = "new";
          # "Stash new unsaved files" = true;
          # "Stash unsaved file changes" = false;
          # "Sync section size with tab positions" = false;
          # "Tab Double Click New Document" = true;
          # "Tab Middle Click Close Document" = true;
          # "Tabbar Tab Limit" = 0;
        };

        # open/save/file select dialog - static sidebar icons size
        "KFileDialog Settings" = {
          "Places Icons Auto-resize" = false;
          "Places Icons Static Size" = 22;
        };

        "KTextEditor Document" = {
          # "Allow End of Line Detection" = true;
          # "Auto Detect Indent" = true;
          # "Auto Reload If Any External Changes Occurs" = false;
          # "Auto Reload If State Is In Version Control" = true;
          # "Auto Save" = false;
          # "Auto Save Interval" = 0;
          # "Auto Save On Focus Out" = false;
          # BOM = false;
          # "Backup Local" = false;
          # "Backup Prefix" = "";
          # "Backup Remote" = false;
          # "Backup Suffix" = "~";
          # "Camel Cursor" = true;
          # Encoding = "UTF-8";
          # "End of Line" = 0;
          # "Indent On Backspace" = true;
          # "Indent On Tab" = true;
          # "Indent On Text Paste" = true;
          # "Indentation Mode" = "normal";
          # "Indentation Width" = 4;
          # "Keep Extra Spaces" = false;
          # "Line Length Limit" = 10000;
          # "Newline at End of File" = true;
          # "On-The-Fly Spellcheck" = false;
          # "Overwrite Mode" = false;
          # "PageUp/PageDown Moves Cursor" = false;
          # "Remove Spaces" = 1;
          # ReplaceTabsDyn = true;
          # "Show Spaces" = 0;
          # "Show Tabs" = true;
          # "Smart Home" = true;
          # "Swap Directory" = "";
          # "Swap File Mode" = 1;
          # "Swap Sync Interval" = 15;
          # "Tab Handling" = 2;
          # "Tab Width" = 4;
          # "Trailing Marker Size" = 1;
          # "Use Editor Config" = true;
          # "Word Wrap" = false;
          # "Word Wrap Column" = 80;
        };

        "KTextEditor Renderer" = {
          # "Animate Bracket Matching" = false;
          # "Auto Color Theme Selection" = false;
          # "Color Theme" = "GitHub Dark";
          # "Line Height Multiplier" = 1;
          # "Show Indentation Lines" = false;
          # "Show Whole Bracket Expression" = false;
          # "Text Font" = "JetBrainsMono Nerd Font Mono,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
          # "Text Font Features" = "";
          # "Word Wrap Marker" = false;
        };

        "KTextEditor View" = {
          # "Allow Mark Menu" = true;
          # "Auto Brackets" = true;
          # "Auto Center Lines" = 0;
          # "Auto Completion" = true;
          # "Auto Completion Preselect First Entry" = true;
          # "Backspace Remove Composed Characters" = false;
          # "Bookmark Menu Sorting" = 0;
          # "Bracket Match Preview" = false;
          # "Chars To Enclose Selection" = "<>(){}[]'\"";
          # "Cycle Through Bookmarks" = true;
          # "Default Mark Type" = 1;
          # "Disable current line highlight if inactive" = false;
          # "Dynamic Word Wrap" = true;
          # "Dynamic Word Wrap Align Indent" = 80;
          # "Dynamic Word Wrap At Static Marker" = false;
          # "Dynamic Word Wrap Indicators" = 1;
          # "Dynamic Wrap not at word boundaries" = false;
          # "Enable Accessibility" = true;
          # "Enable Tab completion" = false;
          # "Enter To Insert Completion" = true;
          # "Fold First Line" = false;
          # "Folding Bar" = true;
          # "Folding Preview" = true;
          # "Hide cursor if inactive" = false;
          # "Icon Bar" = false;
          # "Input Mode" = 1;
          # "Keyword Completion" = true;
          # "Line Modification" = true;
          # "Line Numbers" = true;
          # "Max Clipboard History Entries" = 20;
          # "Maximum Search History Size" = 100;
          # "Mouse Paste At Cursor Position" = false;
          # "Multiple Cursor Modifier" = 134217728;
          # "Persistent Selection" = false;
          # "Scroll Bar Marks" = false;
          # "Scroll Bar Mini Map All" = true;
          # "Scroll Bar Mini Map Width" = 60;
          # "Scroll Bar MiniMap" = true;
          # "Scroll Bar Preview" = true;
          # "Scroll Past End" = false;
          # "Search/Replace Flags" = 140;
          # "Shoe Line Ending Type in Statusbar" = false;
          # "Show Documentation With Completion" = true;
          # "Show File Encoding" = true;
          # "Show Folding Icons On Hover Only" = true;
          # "Show Line Count" = false;
          # "Show Scrollbars" = 0;
          # "Show Statusbar Dictionary" = true;
          # "Show Statusbar Highlighting Mode" = true;
          # "Show Statusbar Input Mode" = true;
          # "Show Statusbar Line Column" = true;
          # "Show Statusbar Tab Settings" = true;
          # "Show Word Count" = false;
          # "Smart Copy Cut" = true;
          # "Statusbar Line Column Compact Mode" = true;
          # "Text Drag And Drop" = true;
          # "User Sets Of Chars To Enclose Selection" = "";
          # "Vi Input Mode Steal Keys" = true;
          # "Vi Relative Line Numbers" = true;
          # "Word Completion" = true;
          # "Word Completion Minimal Word Length" = 3;
          # "Word Completion Remove Tail" = true;
        };

        Konsole = {
          # AutoSyncronizeMode = 0;
          # KonsoleEscKeyBehaviour = true;
          # KonsoleEscKeyExceptions = "vi,vim,nvim,git";
          # RemoveExtension = false;
          # RunPrefix = "";
          # SetEditor = false;
        };

        "Printing/HeaderFooter" = {
          # FooterBackground = "211,211,211";
          # FooterBackgroundEnabled = false;
          # FooterEnabled = true;
          # FooterForeground = "0,0,0";
          # FooterFormatCenter = "";
          # FooterFormatLeft = "";
          # FooterFormatRight = "%U";
          # HeaderBackground = "211,211,211";
          # HeaderBackgroundEnabled = false;
          # HeaderEnabled = true;
          # HeaderFooterFont = "JetBrainsMono Nerd Font Mono,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
          # HeaderForeground = "0,0,0";
          # HeaderFormatCenter = "%f";
          # HeaderFormatLeft = "%y";
          # HeaderFormatRight = "%p";
        };

        "Printing/Layout" = {
          # BackgroundColorEnabled = false;
          # BoxColor = "invalid";
          # BoxEnabled = false;
          # BoxMargin = 6;
          # BoxWidth = 1;
          # Font = "JetBrainsMono Nerd Font Mono,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
        };

        "Printing/Text" = {
          # DontPrintFoldedCode = true;
          # Legend = false;
          # LineNumbers = false;
        };

        filetree = {
          # editShade = "30,78,103";
          # listMode = false;
          # middleClickToClose = false;
          # shadingEnabled = true;
          # showCloseButton = false;
          # showFullPathOnRoots = false;
          # showToolbar = true;
          # sortRole = 0;
          # viewShade = "77,46,91";
        };

        # kategit.lastExecutedGitCmds = "git push origin main";

        lspclient = {
          # AllowedServerCommandLines = "";
          # AutoHover = true;
          # AutoImport = true;
          # BlockedServerCommandLines = "";
          # CompletionDocumentation = true;
          # CompletionParens = true;
          # Diagnostics = true;
          # FormatOnSave = false;
          # HighlightGoto = true;
          # HighlightSymbol = true;
          # IncrementalSync = false;
          # InlayHints = false;
          # Messages = true;
          # ReferencesDeclaration = true;
          # SemanticHighlighting = true;
          # ServerConfiguration = "";
          # ShowCompletions = true;
          # SignatureHelp = true;
          # SymbolDetails = false;
          # SymbolExpand = true;
          # SymbolSort = false;
          # SymbolTree = true;
          # TypeFormatting = false;
        };
      };
    }]
