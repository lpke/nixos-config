{ lib }:

let
  krohnkite = (import ./apps/krohnkite.nix).configFile;
  konsoleYakuake = (import ./apps/konsole-yakuake.nix { inherit lib; }).configFile;
  windowDecorations = (import ./apps/windowDecorations.nix).configFile;
  kwin = (import ./apps/kwin.nix).configFile;

in lib.foldl' lib.recursiveUpdate {} [
    # merged-in configs:
    krohnkite
    konsoleYakuake
    windowDecorations
    kwin
    # all other configs:
    {
      kdeglobals = {
        Shortcuts = {
          RenameFile = "Ctrl+Return";
          # DeleteWordForward = "";
        };

        General = {
          # default terminal
          TerminalApplication = "alacritty";
          TerminalService = "Alacritty.desktop";
          # text rendering
          XftAntialias = true;
          XftHintStyle = "hintslight";
          XftSubPixel = "rgb";
          # fonts
          fixed = "JetBrainsMono Nerd Font Mono,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
          font = "Noto Sans,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
          menuFont = "Noto Sans,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
          smallestReadableFont = "Noto Sans,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
          toolBarFont = "Noto Sans,11,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
        };

        KDE = {
          AnimationDurationFactor = 0.5;
          DndBehavior = "MoveIfSameDevice"; # drag and drop behaviour
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
          "Speedbar Width" = 173;
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
        "KFileDialog Settings"."Places Icons Auto-resize" = false;
        "KFileDialog Settings"."Places Icons Static Size" = 22;
      };

      # dolphin (file explorer)
      dolphinrc.General.ShowFullPath = true;
      dolphinrc.General.DoubleClickViewAction = "show_terminal_panel";
      dolphinrc."KFileDialog Settings"."Places Icons Auto-resize" = false;

      # dolphinrc.Search.SearchTool = "Baloo";
      # baloofilerc.General.dbVersion = 2;
      # baloofilerc.General."exclude filters" = "*~,*.part,*.o,*.la,*.lo,*.loT,*.moc,moc_*.cpp,qrc_*.cpp,ui_*.h,cmake_install.cmake,CMakeCache.txt,CTestTestfile.cmake,libtool,config.status,confdefs.h,autom4te,conftest,confstat,Makefile.am,*.gcode,.ninja_deps,.ninja_log,build.ninja,*.csproj,*.m4,*.rej,*.gmo,*.pc,*.omf,*.aux,*.tmp,*.po,*.vm*,*.nvram,*.rcore,*.swp,*.swap,lzo,litmain.sh,*.orig,.histfile.*,.xsession-errors*,*.map,*.so,*.a,*.db,*.qrc,*.ini,*.init,*.img,*.vdi,*.vbox*,vbox.log,*.qcow2,*.vmdk,*.vhd,*.vhdx,*.sql,*.sql.gz,*.ytdl,*.tfstate*,*.class,*.pyc,*.pyo,*.elc,*.qmlc,*.jsc,*.fastq,*.fq,*.gb,*.fasta,*.fna,*.gbff,*.faa,po,CVS,.svn,.git,_darcs,.bzr,.hg,CMakeFiles,CMakeTmp,CMakeTmpQmake,.moc,.obj,.pch,.uic,.npm,.yarn,.yarn-cache,__pycache__,node_modules,node_packages,nbproject,.terraform,.venv,venv,core-dumps,lost+found";
      # baloofilerc.General."exclude filters version" = 9;
      # baloofilerc.General."index hidden folders" = true;
      # kactivitymanagerdrc.activities.d047f45f-b07f-433d-8d9b-aa1cc7ad7016 = "Default";
      # kactivitymanagerdrc.main.currentActivity = "d047f45f-b07f-433d-8d9b-aa1cc7ad7016";
      # katerc.General."Allow Tab Scrolling" = true;
      # katerc.General."Auto Hide Tabs" = false;
      # katerc.General."Close After Last" = false;
      # katerc.General."Close documents with window" = true;
      # katerc.General."Cycle To First Tab" = true;
      # katerc.General."Days Meta Infos" = 30;
      # katerc.General."Diagnostics Limit" = 12000;
      # katerc.General."Diff Show Style" = 0;
      # katerc.General."Elide Tab Text" = false;
      # katerc.General."Enable Context ToolView" = false;
      # katerc.General."Expand Tabs" = false;
      # katerc.General."Icon size for left and right sidebar buttons" = 32;
      # katerc.General."Last Session" = "chezmoi";
      # katerc.General."Modified Notification" = false;
      # katerc.General."Mouse back button action" = 0;
      # katerc.General."Mouse forward button action" = 0;
      # katerc.General."Open New Tab To The Right Of Current" = false;
      # katerc.General."Output History Limit" = 100;
      # katerc.General."Output With Date" = false;
      # katerc.General."Quickopen Filter Mode" = 0;
      # katerc.General."Quickopen List Mode" = true;
      # katerc.General."Recent File List Entry Count" = 10;
      # katerc.General."Restore Window Configuration" = true;
      # katerc.General."SDI Mode" = false;
      # katerc.General."Save Meta Infos" = true;
      # katerc.General."Session Manager Sort Column" = 0;
      # katerc.General."Session Manager Sort Order" = 0;
      # katerc.General."Show Full Path in Title" = false;
      # katerc.General."Show Menu Bar" = true;
      # katerc.General."Show Status Bar" = true;
      # katerc.General."Show Symbol In Navigation Bar" = true;
      # katerc.General."Show Tab Bar" = true;
      # katerc.General."Show Tabs Close Button" = true;
      # katerc.General."Show Url Nav Bar" = true;
      # katerc.General."Show output view for message type" = 1;
      # katerc.General."Show text for left and right sidebar" = false;
      # katerc.General."Show welcome view for new window" = false;
      # katerc.General."Startup Session" = "new";
      # katerc.General."Stash new unsaved files" = true;
      # katerc.General."Stash unsaved file changes" = false;
      # katerc.General."Sync section size with tab positions" = false;
      # katerc.General."Tab Double Click New Document" = true;
      # katerc.General."Tab Middle Click Close Document" = true;
      # katerc.General."Tabbar Tab Limit" = 0;
      # katerc."KFileDialog Settings"."Places Icons Auto-resize" = false;
      # katerc."KFileDialog Settings"."Places Icons Static Size" = 22;
      # katerc."KTextEditor Document"."Allow End of Line Detection" = true;
      # katerc."KTextEditor Document"."Auto Detect Indent" = true;
      # katerc."KTextEditor Document"."Auto Reload If Any External Changes Occurs" = false;
      # katerc."KTextEditor Document"."Auto Reload If State Is In Version Control" = true;
      # katerc."KTextEditor Document"."Auto Save" = false;
      # katerc."KTextEditor Document"."Auto Save Interval" = 0;
      # katerc."KTextEditor Document"."Auto Save On Focus Out" = false;
      # katerc."KTextEditor Document".BOM = false;
      # katerc."KTextEditor Document"."Backup Local" = false;
      # katerc."KTextEditor Document"."Backup Prefix" = "";
      # katerc."KTextEditor Document"."Backup Remote" = false;
      # katerc."KTextEditor Document"."Backup Suffix" = "~";
      # katerc."KTextEditor Document"."Camel Cursor" = true;
      # katerc."KTextEditor Document".Encoding = "UTF-8";
      # katerc."KTextEditor Document"."End of Line" = 0;
      # katerc."KTextEditor Document"."Indent On Backspace" = true;
      # katerc."KTextEditor Document"."Indent On Tab" = true;
      # katerc."KTextEditor Document"."Indent On Text Paste" = true;
      # katerc."KTextEditor Document"."Indentation Mode" = "normal";
      # katerc."KTextEditor Document"."Indentation Width" = 4;
      # katerc."KTextEditor Document"."Keep Extra Spaces" = false;
      # katerc."KTextEditor Document"."Line Length Limit" = 10000;
      # katerc."KTextEditor Document"."Newline at End of File" = true;
      # katerc."KTextEditor Document"."On-The-Fly Spellcheck" = false;
      # katerc."KTextEditor Document"."Overwrite Mode" = false;
      # katerc."KTextEditor Document"."PageUp/PageDown Moves Cursor" = false;
      # katerc."KTextEditor Document"."Remove Spaces" = 1;
      # katerc."KTextEditor Document".ReplaceTabsDyn = true;
      # katerc."KTextEditor Document"."Show Spaces" = 0;
      # katerc."KTextEditor Document"."Show Tabs" = true;
      # katerc."KTextEditor Document"."Smart Home" = true;
      # katerc."KTextEditor Document"."Swap Directory" = "";
      # katerc."KTextEditor Document"."Swap File Mode" = 1;
      # katerc."KTextEditor Document"."Swap Sync Interval" = 15;
      # katerc."KTextEditor Document"."Tab Handling" = 2;
      # katerc."KTextEditor Document"."Tab Width" = 4;
      # katerc."KTextEditor Document"."Trailing Marker Size" = 1;
      # katerc."KTextEditor Document"."Use Editor Config" = true;
      # katerc."KTextEditor Document"."Word Wrap" = false;
      # katerc."KTextEditor Document"."Word Wrap Column" = 80;
      # katerc."KTextEditor Renderer"."Animate Bracket Matching" = false;
      # katerc."KTextEditor Renderer"."Auto Color Theme Selection" = false;
      # katerc."KTextEditor Renderer"."Color Theme" = "GitHub Dark";
      # katerc."KTextEditor Renderer"."Line Height Multiplier" = 1;
      # katerc."KTextEditor Renderer"."Show Indentation Lines" = false;
      # katerc."KTextEditor Renderer"."Show Whole Bracket Expression" = false;
      # katerc."KTextEditor Renderer"."Text Font" = "JetBrainsMono Nerd Font Mono,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
      # katerc."KTextEditor Renderer"."Text Font Features" = "";
      # katerc."KTextEditor Renderer"."Word Wrap Marker" = false;
      # katerc."KTextEditor View"."Allow Mark Menu" = true;
      # katerc."KTextEditor View"."Auto Brackets" = true;
      # katerc."KTextEditor View"."Auto Center Lines" = 0;
      # katerc."KTextEditor View"."Auto Completion" = true;
      # katerc."KTextEditor View"."Auto Completion Preselect First Entry" = true;
      # katerc."KTextEditor View"."Backspace Remove Composed Characters" = false;
      # katerc."KTextEditor View"."Bookmark Menu Sorting" = 0;
      # katerc."KTextEditor View"."Bracket Match Preview" = false;
      # katerc."KTextEditor View"."Chars To Enclose Selection" = "<>(){}[]'\"";
      # katerc."KTextEditor View"."Cycle Through Bookmarks" = true;
      # katerc."KTextEditor View"."Default Mark Type" = 1;
      # katerc."KTextEditor View"."Disable current line highlight if inactive" = false;
      # katerc."KTextEditor View"."Dynamic Word Wrap" = true;
      # katerc."KTextEditor View"."Dynamic Word Wrap Align Indent" = 80;
      # katerc."KTextEditor View"."Dynamic Word Wrap At Static Marker" = false;
      # katerc."KTextEditor View"."Dynamic Word Wrap Indicators" = 1;
      # katerc."KTextEditor View"."Dynamic Wrap not at word boundaries" = false;
      # katerc."KTextEditor View"."Enable Accessibility" = true;
      # katerc."KTextEditor View"."Enable Tab completion" = false;
      # katerc."KTextEditor View"."Enter To Insert Completion" = true;
      # katerc."KTextEditor View"."Fold First Line" = false;
      # katerc."KTextEditor View"."Folding Bar" = true;
      # katerc."KTextEditor View"."Folding Preview" = true;
      # katerc."KTextEditor View"."Hide cursor if inactive" = false;
      # katerc."KTextEditor View"."Icon Bar" = false;
      # katerc."KTextEditor View"."Input Mode" = 1;
      # katerc."KTextEditor View"."Keyword Completion" = true;
      # katerc."KTextEditor View"."Line Modification" = true;
      # katerc."KTextEditor View"."Line Numbers" = true;
      # katerc."KTextEditor View"."Max Clipboard History Entries" = 20;
      # katerc."KTextEditor View"."Maximum Search History Size" = 100;
      # katerc."KTextEditor View"."Mouse Paste At Cursor Position" = false;
      # katerc."KTextEditor View"."Multiple Cursor Modifier" = 134217728;
      # katerc."KTextEditor View"."Persistent Selection" = false;
      # katerc."KTextEditor View"."Scroll Bar Marks" = false;
      # katerc."KTextEditor View"."Scroll Bar Mini Map All" = true;
      # katerc."KTextEditor View"."Scroll Bar Mini Map Width" = 60;
      # katerc."KTextEditor View"."Scroll Bar MiniMap" = true;
      # katerc."KTextEditor View"."Scroll Bar Preview" = true;
      # katerc."KTextEditor View"."Scroll Past End" = false;
      # katerc."KTextEditor View"."Search/Replace Flags" = 140;
      # katerc."KTextEditor View"."Shoe Line Ending Type in Statusbar" = false;
      # katerc."KTextEditor View"."Show Documentation With Completion" = true;
      # katerc."KTextEditor View"."Show File Encoding" = true;
      # katerc."KTextEditor View"."Show Folding Icons On Hover Only" = true;
      # katerc."KTextEditor View"."Show Line Count" = false;
      # katerc."KTextEditor View"."Show Scrollbars" = 0;
      # katerc."KTextEditor View"."Show Statusbar Dictionary" = true;
      # katerc."KTextEditor View"."Show Statusbar Highlighting Mode" = true;
      # katerc."KTextEditor View"."Show Statusbar Input Mode" = true;
      # katerc."KTextEditor View"."Show Statusbar Line Column" = true;
      # katerc."KTextEditor View"."Show Statusbar Tab Settings" = true;
      # katerc."KTextEditor View"."Show Word Count" = false;
      # katerc."KTextEditor View"."Smart Copy Cut" = true;
      # katerc."KTextEditor View"."Statusbar Line Column Compact Mode" = true;
      # katerc."KTextEditor View"."Text Drag And Drop" = true;
      # katerc."KTextEditor View"."User Sets Of Chars To Enclose Selection" = "";
      # katerc."KTextEditor View"."Vi Input Mode Steal Keys" = true;
      # katerc."KTextEditor View"."Vi Relative Line Numbers" = true;
      # katerc."KTextEditor View"."Word Completion" = true;
      # katerc."KTextEditor View"."Word Completion Minimal Word Length" = 3;
      # katerc."KTextEditor View"."Word Completion Remove Tail" = true;
      # katerc.Konsole.AutoSyncronizeMode = 0;
      # katerc.Konsole.KonsoleEscKeyBehaviour = true;
      # katerc.Konsole.KonsoleEscKeyExceptions = "vi,vim,nvim,git";
      # katerc.Konsole.RemoveExtension = false;
      # katerc.Konsole.RunPrefix = "";
      # katerc.Konsole.SetEditor = false;
      # katerc."Printing/HeaderFooter".FooterBackground = "211,211,211";
      # katerc."Printing/HeaderFooter".FooterBackgroundEnabled = false;
      # katerc."Printing/HeaderFooter".FooterEnabled = true;
      # katerc."Printing/HeaderFooter".FooterForeground = "0,0,0";
      # katerc."Printing/HeaderFooter".FooterFormatCenter = "";
      # katerc."Printing/HeaderFooter".FooterFormatLeft = "";
      # katerc."Printing/HeaderFooter".FooterFormatRight = "%U";
      # katerc."Printing/HeaderFooter".HeaderBackground = "211,211,211";
      # katerc."Printing/HeaderFooter".HeaderBackgroundEnabled = false;
      # katerc."Printing/HeaderFooter".HeaderEnabled = true;
      # katerc."Printing/HeaderFooter".HeaderFooterFont = "JetBrainsMono Nerd Font Mono,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
      # katerc."Printing/HeaderFooter".HeaderForeground = "0,0,0";
      # katerc."Printing/HeaderFooter".HeaderFormatCenter = "%f";
      # katerc."Printing/HeaderFooter".HeaderFormatLeft = "%y";
      # katerc."Printing/HeaderFooter".HeaderFormatRight = "%p";
      # katerc."Printing/Layout".BackgroundColorEnabled = false;
      # katerc."Printing/Layout".BoxColor = "invalid";
      # katerc."Printing/Layout".BoxEnabled = false;
      # katerc."Printing/Layout".BoxMargin = 6;
      # katerc."Printing/Layout".BoxWidth = 1;
      # katerc."Printing/Layout".Font = "JetBrainsMono Nerd Font Mono,12,-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
      # katerc."Printing/Text".DontPrintFoldedCode = true;
      # katerc."Printing/Text".Legend = false;
      # katerc."Printing/Text".LineNumbers = false;
      # katerc.filetree.editShade = "30,78,103";
      # katerc.filetree.listMode = false;
      # katerc.filetree.middleClickToClose = false;
      # katerc.filetree.shadingEnabled = true;
      # katerc.filetree.showCloseButton = false;
      # katerc.filetree.showFullPathOnRoots = false;
      # katerc.filetree.showToolbar = true;
      # katerc.filetree.sortRole = 0;
      # katerc.filetree.viewShade = "77,46,91";
      # katerc.kategit.lastExecutedGitCmds = "git push origin main";
      # katerc.lspclient.AllowedServerCommandLines = "";
      # katerc.lspclient.AutoHover = true;
      # katerc.lspclient.AutoImport = true;
      # katerc.lspclient.BlockedServerCommandLines = "";
      # katerc.lspclient.CompletionDocumentation = true;
      # katerc.lspclient.CompletionParens = true;
      # katerc.lspclient.Diagnostics = true;
      # katerc.lspclient.FormatOnSave = false;
      # katerc.lspclient.HighlightGoto = true;
      # katerc.lspclient.HighlightSymbol = true;
      # katerc.lspclient.IncrementalSync = false;
      # katerc.lspclient.InlayHints = false;
      # katerc.lspclient.Messages = true;
      # katerc.lspclient.ReferencesDeclaration = true;
      # katerc.lspclient.SemanticHighlighting = true;
      # katerc.lspclient.ServerConfiguration = "";
      # katerc.lspclient.ShowCompletions = true;
      # katerc.lspclient.SignatureHelp = true;
      # katerc.lspclient.SymbolDetails = false;
      # katerc.lspclient.SymbolExpand = true;
      # katerc.lspclient.SymbolSort = false;
      # katerc.lspclient.SymbolTree = true;
      # katerc.lspclient.TypeFormatting = false;
      # kiorc.Confirmations.ConfirmDelete = true;
      # kiorc.Confirmations.ConfirmEmptyTrash = true;
      # kiorc.Confirmations.ConfirmTrash = false;
      # kiorc."Executable scripts".behaviourOnLaunch = "alwaysAsk";
      # krunnerrc.Plugins.baloosearchEnabled = true;
      # krunnerrc.Plugins.krunner_appstreamEnabled = false;
      # krunnerrc.Plugins.krunner_webshortcutsEnabled = false;
      # krunnerrc."Plugins/Favorites".plugins = "krunner_sessions,krunner_powerdevil,krunner_services,krunner_systemsettings";
      # kscreenlockerrc.Daemon.Autolock = false;
      # kscreenlockerrc.Daemon.Timeout = 0;
      # kservicemenurc.Show.compressfileitemaction = true;
      # kservicemenurc.Show.extractfileitemaction = true;
      # kservicemenurc.Show.filelight = true;
      # kservicemenurc.Show.forgetfileitemaction = true;
      # kservicemenurc.Show.installFont = true;
      # kservicemenurc.Show.kactivitymanagerd_fileitem_linking_plugin = true;
      # kservicemenurc.Show.kio-admin = true;
      # kservicemenurc.Show.makefileactions = true;
      # kservicemenurc.Show.mountisoaction = true;
      # kservicemenurc.Show.movetonewfolderitemaction = true;
      # kservicemenurc.Show.runInKonsole = true;
      # kservicemenurc.Show.setfoldericonitemaction = true;
      # kservicemenurc.Show.slideshowfileitemaction = true;
      # kservicemenurc.Show.tagsfileitemaction = true;
      # kservicemenurc.Show.wallpaperfileitemaction = true;
      # ksmserverrc.General.loginMode = "restoreSavedSession";
      # ktrashrc."\\/home\\/luke\\/.local\\/share\\/Trash".Days = 7;
      # ktrashrc."\\/home\\/luke\\/.local\\/share\\/Trash".LimitReachedAction = 0;
      # ktrashrc."\\/home\\/luke\\/.local\\/share\\/Trash".Percent = 10;
      # ktrashrc."\\/home\\/luke\\/.local\\/share\\/Trash".UseSizeLimit = true;
      # ktrashrc."\\/home\\/luke\\/.local\\/share\\/Trash".UseTimeLimit = false;
      # kwalletrc.Wallet."First Use" = false;
      # plasma-localerc.Formats.LANG = "en_AU.UTF-8";
      # plasmanotifyrc."Applications/vivaldi-stable".Seen = true;
      # plasmanotifyrc.Notifications.PopupPosition = "BottomRight";
      # plasmaparc.General.AudioFeedback = false;
      # plasmarc.Wallpapers.usersWallpapers = "";
      # spectaclerc.Annotations.annotationToolType = 1;
      # spectaclerc.ImageSave.imageFilenameTemplate = "screenshot_<yyyy>-<MM>-<dd>_<HH><mm><ss>";
      # spectaclerc.ImageSave.lastImageSaveLocation = "file:///home/luke/Pictures/Screenshots/screenshot_2026-01-20_164806.png";
      # spectaclerc.ImageSave.translatedScreenshotsFolder = "Screenshots";
      # spectaclerc.VideoSave.preferredVideoFormat = 2;
      # spectaclerc.VideoSave.translatedScreencastsFolder = "Screencasts";
      # spectaclerc.VideoSave.videoFilenameTemplate = "recording_<yyyy>-<MM>-<dd>_<HH><mm><ss>";
      # spectaclerc.VideoSave.videoSaveLocation = "file:///home/luke/Videos/Recordings/";
    }]
