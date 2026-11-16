{ lib, pkgs, ... }:
{
  # Plasma Manager writes the files but does not ask the running KWin to reread
  # them. Reconfigure keeps the compositor and enabled scripts alive.
  home.activation.reloadKwinSettings = lib.hm.dag.entryAfter [ "configure-plasma" ] ''
    if [[ $(${pkgs.systemd}/bin/busctl --user call org.freedesktop.DBus \
        /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.kde.KWin 2>/dev/null) == "b true" ]]; then
      run ${pkgs.systemd}/bin/busctl --user --auto-start=no call \
        org.kde.KWin /KWin org.kde.KWin reconfigure
    fi
  '';
}
