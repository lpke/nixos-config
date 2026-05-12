# ══════════════════════════════════════════════════════════════════
# MIMEAPPS - Default Applications and File Associations
# ══════════════════════════════════════════════════════════════════
# To test what to add here, use the KDE GUI: System Settings > Default Applications
# > File Associations. And then check ~/.config/mimeapps.list

let
  textApps = ["nvim.desktop" "org.kde.kate.desktop" "org.kde.kwrite.desktop" "okularApplication_txt.desktop"];
  browserApps = ["vivaldi-stable.desktop"];
  imageApps = ["org.kde.gwenview.desktop"];
  rawPhotoApps = ["darktable.desktop"];
  musicApps = ["org.kde.elisa.desktop"];
  pdfApps = ["org.kde.okular.desktop"];
  terminalApps = ["Alacritty.desktop"];
  archiveApps = ["org.kde.ark.desktop"];
  fileManagerApps = ["org.kde.dolphin.desktop"];

in {
  # apps that launch by default on double-click
  defaultApplications = {
    # Browser
    "x-scheme-handler/http" = browserApps;
    "x-scheme-handler/https" = browserApps;
    "x-scheme-handler/about" = browserApps;
    "x-scheme-handler/unknown" = browserApps;
    "application/xhtml+xml" = browserApps;

    # Images
    "image/png" = imageApps;
    "image/jpeg" = imageApps;
    "image/gif" = imageApps;
    "image/webp" = imageApps;
    "image/svg+xml" = imageApps;
    "image/bmp" = imageApps;
    "image/tiff" = imageApps;
    "image/x-adobe-dng" = rawPhotoApps;

    # Music
    "audio/mpeg" = musicApps;
    "audio/mp3" = musicApps;
    "audio/flac" = musicApps;
    "audio/ogg" = musicApps;
    "audio/wav" = musicApps;
    "audio/x-wav" = musicApps;
    "audio/aac" = musicApps;
    "audio/x-m4a" = musicApps;

    # Text (comprehensive list)
    "text/cache-manifest" = textApps;
    "text/css" = textApps;
    "text/csv-schema" = textApps;
    "text/html" = textApps;
    "text/htmlh" = textApps;
    "text/javascript" = textApps;
    "text/jscript.encode" = textApps;
    "text/julia" = textApps;
    "text/markdown" = textApps;
    "text/org" = textApps;
    "text/plain" = textApps;
    "text/rfc822-headers" = textApps;
    "text/rust" = textApps;
    "text/sgml" = textApps;
    "text/tcl" = textApps;
    "text/troff" = textApps;
    "text/turtle" = textApps;
    "text/vbscript" = textApps;
    "text/vbscript.encode" = textApps;
    "text/vcard" = textApps;
    "text/vnd.abc" = textApps;
    "text/vnd.familysearch.gedcom" = textApps;
    "text/vnd.graphviz" = textApps;
    "text/vnd.kde.kcrash-report" = textApps;
    "text/vnd.rn-realtext" = textApps;
    "text/vnd.senx.warpscript" = textApps;
    "text/vnd.sun.j2me.app-descriptor" = textApps;
    "text/vnd.trolltech.linguist" = textApps;
    "text/vnd.wap.wml" = textApps;
    "text/vnd.wap.wmlscript" = textApps;
    "text/vtt" = textApps;
    "text/x-adasrc" = textApps;
    "text/x-authors" = textApps;
    "text/x-basic" = textApps;
    "text/x-bibtex" = textApps;
    "text/x-blueprint" = textApps;
    "text/x-c++hdr" = textApps;
    "text/x-c++src" = textApps;
    "text/x-changelog" = textApps;
    "text/x-chdr" = textApps;
    "text/x-cmake" = textApps;
    "text/x-cobol" = textApps;
    "text/x-common-lisp" = textApps;
    "text/x-component" = textApps;
    "text/x-copying" = textApps;
    "text/x-credits" = textApps;
    "text/x-crystal" = textApps;
    "text/x-csharp" = textApps;
    "text/x-csrc" = textApps;
    "text/x-dbus-service" = textApps;
    "text/x-dcl" = textApps;
    "text/x-devicetree-binary" = textApps;
    "text/x-devicetree-source" = textApps;
    "text/x-dsl" = textApps;
    "text/x-dsrc" = textApps;
    "text/x-eiffel" = textApps;
    "text/x-elixir" = textApps;
    "text/x-emacs-lisp" = textApps;
    "text/x-erlang" = textApps;
    "text/x-fortran" = textApps;
    "text/x-gcode-gx" = textApps;
    "text/x-genie" = textApps;
    "text/x-gettext-translation" = textApps;
    "text/x-gettext-translation-template" = textApps;
    "text/x-gherkin" = textApps;
    "text/x-go" = textApps;
    "text/x-google-video-pointer" = textApps;
    "text/x-gradle" = textApps;
    "text/x-groovy" = textApps;
    "text/x-haskell" = textApps;
    "text/x-hex" = textApps;
    "text/x-iMelody" = textApps;
    "text/x-idl" = textApps;
    "text/x-install" = textApps;
    "text/x-iptables" = textApps;
    "text/x-java" = textApps;
    "text/x-kaitai-struct" = textApps;
    "text/x-katefilelist" = textApps;
    "text/x-kotlin" = textApps;
    "text/x-ldif" = textApps;
    "text/x-lilypond" = textApps;
    "text/x-literate-haskell" = textApps;
    "text/x-log" = textApps;
    "text/x-lua" = textApps;
    "text/x-makefile" = textApps;
    "text/x-matlab" = textApps;
    "text/x-maven+xml" = textApps;
    "text/x-meson" = textApps;
    "text/x-microdvd" = textApps;
    "text/x-moc" = textApps;
    "text/x-modelica" = textApps;
    "text/x-mof" = textApps;
    "text/x-mpl2" = textApps;
    "text/x-mpsub" = textApps;
    "text/x-mrml" = textApps;
    "text/x-ms-regedit" = textApps;
    "text/x-mup" = textApps;
    "text/x-nfo" = textApps;
    "text/x-nim" = textApps;
    "text/x-nimscript" = textApps;
    "text/x-objc++src" = textApps;
    "text/x-objcsrc" = textApps;
    "text/x-ocaml" = textApps;
    "text/x-ocl" = textApps;
    "text/x-ooc" = textApps;
    "text/x-opencl-src" = textApps;
    "text/x-opml+xml" = textApps;
    "text/x-pascal" = textApps;
    "text/x-patch" = textApps;
    "text/x-python" = textApps;
    "text/x-python3" = textApps;
    "text/x-qml" = textApps;
    "text/x-readme" = textApps;
    "text/x-reject" = textApps;
    "text/x-rpm-spec" = textApps;
    "text/x-rst" = textApps;
    "text/x-sagemath" = textApps;
    "text/x-sass" = textApps;
    "text/x-scala" = textApps;
    "text/x-scheme" = textApps;
    "text/x-scons" = textApps;
    "text/x-scss" = textApps;
    "text/x-setext" = textApps;
    "text/x-ssa" = textApps;
    "text/x-subviewer" = textApps;
    "text/x-svhdr" = textApps;
    "text/x-svsrc" = textApps;
    "text/x-systemd-unit" = textApps;
    "text/x-tex" = textApps;
    "text/x-texinfo" = textApps;
    "text/x-todo-txt" = textApps;
    "text/x-troff-me" = textApps;
    "text/x-troff-mm" = textApps;
    "text/x-troff-ms" = textApps;
    "text/x-xmi" = textApps;
    "text/x-xslfo" = textApps;

    # PDF
    "application/pdf" = pdfApps;

    # File Manager
    "inode/directory" = fileManagerApps;
    "x-scheme-handler/file" = fileManagerApps;

    # Terminal
    "x-scheme-handler/terminal" = terminalApps;

    # Archives
    "application/zip" = archiveApps;
    "application/x-tar" = archiveApps;
    "application/x-gzip" = archiveApps;
    "application/x-bzip2" = archiveApps;
    "application/x-xz" = archiveApps;
    "application/x-7z-compressed" = archiveApps;
    "application/x-rar" = archiveApps;
    "application/gzip" = archiveApps;

    # Discord
    "x-scheme-handler/discord-409416265891971072" = "discord-409416265891971072.desktop";
  };
}
