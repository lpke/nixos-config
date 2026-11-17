{ lib, stdenvNoCC, python3, makeWrapper, krohnkite, qt6, systemd, kdePackages, alacritty }:
let
  python = python3.withPackages (ps: [ ps.pyqt6 ]);
in stdenvNoCC.mkDerivation {
  pname = "krohnkite-control";
  version = "1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper qt6.wrapQtAppsHook ];
  buildInputs = [ qt6.qtbase qt6.qtsvg qt6.qtwayland ];
  dontWrapQtApps = true;
  doCheck = true;
  checkPhase = ''
    export PYTHONPATH="$PWD:${../tray-support}"
    export QT_QPA_PLATFORM=offscreen
    unset DISPLAY WAYLAND_DISPLAY
    export DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent
    export XDG_CACHE_HOME="$TMPDIR/cache"
    ${python}/bin/python -B -m unittest -v
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/krohnkite-control" "$out/bin" "$out/share/icons/hicolor/scalable/apps"
    cp control.py lifecycle.py tray.py tiling.svg help.md "$out/lib/krohnkite-control/"
    cp ${../tray-support/tray_icon.py} "$out/lib/krohnkite-control/tray_icon.py"
    cp tiling.svg "$out/share/icons/hicolor/scalable/apps/krohnkite.svg"
    for entry in control tray; do
      name=krohnkite
      if [ "$entry" = tray ]; then name=krohnkite-tray; fi
      makeWrapper ${python}/bin/python "$out/bin/$name" \
        --add-flags "$out/lib/krohnkite-control/$entry.py" \
        --set KROHNKITE_PACKAGE ${krohnkite}/share/kwin/scripts/krohnkite \
        --set PYTHONDONTWRITEBYTECODE 1 \
        --prefix PYTHONPATH : "$out/lib/krohnkite-control" \
        --prefix PATH : "$out/bin" \
        --prefix PATH : ${lib.makeBinPath [ systemd kdePackages.kconfig alacritty ]}
    done
    wrapQtApp "$out/bin/krohnkite-tray"
    runHook postInstall
  '';
  meta.mainProgram = "krohnkite";
}
