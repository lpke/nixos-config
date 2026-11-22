{ lib, stdenvNoCC, python3, makeWrapper, qt6, wl-clipboard, alacritty }:
let python = python3.withPackages (ps: [ ps.pyqt6 ]);
in stdenvNoCC.mkDerivation {
  pname = "app-tray";
  version = "1.0";
  src = ../tray-support;
  nativeBuildInputs = [ makeWrapper qt6.wrapQtAppsHook ];
  buildInputs = [ qt6.qtbase qt6.qtsvg qt6.qtwayland ];
  dontWrapQtApps = true;
  installPhase = ''
    mkdir -p "$out/bin" "$out/lib/app-tray"
    cp tray_icon.py "$out/lib/app-tray/"
    cat > "$out/bin/app-tray-daemon" <<'SCRIPT'
#!${stdenvNoCC.shell}
exec ${python}/bin/python "$HOME/.local/share/app-tray/tray_linux.py" "$@"
SCRIPT
    chmod +x "$out/bin/app-tray-daemon"
    # wl-copy copies under Wayland; Alacritty opens the log terminal.
    wrapProgram "$out/bin/app-tray-daemon" \
      --prefix PYTHONPATH : "$out/lib/app-tray" \
      --prefix PATH : "${lib.makeBinPath [ wl-clipboard alacritty ]}"
    wrapQtApp "$out/bin/app-tray-daemon"
  '';
}
