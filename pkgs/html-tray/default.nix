{ lib, stdenvNoCC, python3, makeWrapper, qt6, wl-clipboard }:
let python = python3.withPackages (ps: [ ps.pyqt6 ]);
in stdenvNoCC.mkDerivation {
  pname = "html-tray";
  version = "1.0";
  src = ../tray-support;
  nativeBuildInputs = [ makeWrapper qt6.wrapQtAppsHook ];
  buildInputs = [ qt6.qtbase qt6.qtsvg qt6.qtwayland ];
  dontWrapQtApps = true;
  installPhase = ''
    mkdir -p "$out/bin" "$out/lib/html-tray"
    cp tray_icon.py "$out/lib/html-tray/"
    cat > "$out/bin/html-tray-daemon" <<'SCRIPT'
#!${stdenvNoCC.shell}
exec ${python}/bin/python "$HOME/.local/share/html-control/tray_linux.py" "$@"
SCRIPT
    chmod +x "$out/bin/html-tray-daemon"
    wrapProgram "$out/bin/html-tray-daemon" \
      --prefix PYTHONPATH : "$out/lib/html-tray" \
      --prefix PATH : "${lib.makeBinPath [ python3 wl-clipboard ]}"
    wrapQtApp "$out/bin/html-tray-daemon"
  '';
}
