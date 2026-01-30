# ══════════════════════════════════════════════════════════════════
# AUTOSTART
# ══════════════════════════════════════════════════════════════════
# Desktop Entry Specification:
# https://specifications.freedesktop.org/desktop-entry/latest/

{
  "autostart/yakuake.desktop" = {
    enable = true;
    text = ''
      [Desktop Entry]
      Categories=Qt;KDE;System;TerminalEmulator;
      Comment=A drop-down terminal emulator based on KDE Konsole technology.
      DBusActivatable=true
      Exec=yakuake
      GenericName=Drop-down Terminal
      Icon=yakuake
      Name=Yakuake
      StartupNotify=false
      Terminal=false
      Type=Application
    '';
  };

  "autostart/libratbag.desktop" = {
    enable = true;
    text = ''
      [Desktop Entry]
      Exec=sudo ratbagd
      Icon=application-x-shellscript
      Name=libratbag (for Piper)
      Type=Application
      X-KDE-AutostartScript=true
    '';
  };
}
