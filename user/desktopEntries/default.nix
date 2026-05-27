# ══════════════════════════════════════════════════════════════════
# DESKTOP ENTRIES - Custom Application Launchers
# ══════════════════════════════════════════════════════════════════
# These override system .desktop files that are typically placed in:
# ~/.local/share/applications/
# The files generated end up at /nix/store/<app>.desktop/share/applications/
#
# Desktop Entry Specification:
# https://specifications.freedesktop.org/desktop-entry/latest/

{
  # Vivaldi with X11 backend
  # (fixes rendering bugs on Wayland and webcam issues)
  vivaldi-stable = {
    name = "Vivaldi";
    icon = "vivaldi";
    genericName = "Web Browser";
    comment = "Access the Internet";
    exec = "vivaldi %U --ozone-platform=x11";
    type = "Application";
    terminal = false;
    categories = [ "Network" "WebBrowser" ];
    mimeType = [
      "application/pdf"
      "application/rdf+xml"
      "application/rss+xml"
      "application/xhtml+xml"
      "application/xhtml_xml"
      "application/xml"
      "image/gif"
      "image/jpeg"
      "image/png"
      "image/webp"
      "text/html"
      "text/xml"
      "x-scheme-handler/ftp"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
      "x-scheme-handler/mailto"
    ];
    startupNotify = true;

    settings = {
      StartupWMClass = "Vivaldi-stable";
    };

    actions = {
      new-window = {
        name = "New Window";
        exec = "vivaldi --ozone-platform=x11 --new-window";
      };
      new-private-window = {
        name = "New Private Window";
        exec = "vivaldi --ozone-platform=x11 --incognito";
      };
    };
  };

  google-chrome-debug = {
    name = "Chrome Debug";
    icon = "google-chrome";
    genericName = "Web Browser";
    comment = "Launch Chrome with localhost remote debugging for MCP co-debugging";
    exec = "chrome-debug %U";
    type = "Application";
    terminal = false;
    categories = [ "Network" "WebBrowser" "Development" ];
    startupNotify = true;

    settings = {
      StartupWMClass = "google-chrome";
    };
  };

  # Battle.net (via Steam)
  battlenet = {
    name = "Battle.net";
    comment = "Launch via Steam";
    exec = "steam steam://rungameid/14634017402250067968";
    icon = "/home/luke/.local/share/icons/battlenet.png";
    type = "Application";
    terminal = false;
    categories = [ "Game" ];
  };

  adobe-dng-converter = {
    name = "Adobe DNG Converter";
    genericName = "DNG Converter";
    comment = "Launch Adobe DNG Converter under Wine";
    exec = "adobe-dng-converter --gui-launcher";
    icon = "49AA_Adobe DNG Converter.0";
    type = "Application";
    terminal = false;
    categories = [ "Graphics" "Photography" ];
    startupNotify = true;
  };
}
