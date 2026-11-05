{ pkgs, ... }:
{
  # Chezmoi owns the writable upstream editor and desktop entries. Keep the GUI
  # updater dependency reachable from desktop launches as well as shells.
  home.file.".local/share/vscode/zenity".source = "${pkgs.zenity}/bin/zenity";
  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/vscode" = [ "code-url-handler.desktop" ];
    "x-scheme-handler/vscode-update" = [ "code-update.desktop" ];
  };
}
