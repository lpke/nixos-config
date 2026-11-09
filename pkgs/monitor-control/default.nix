{ lib, stdenvNoCC, python3, makeWrapper, qt6, kdePackages, systemd }:
let
  python = python3.withPackages (ps: [ ps.pyqt6 ]);
in
stdenvNoCC.mkDerivation {
  pname = "monitor-control";
  version = "1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper qt6.wrapQtAppsHook ];
  buildInputs = [ qt6.qtbase qt6.qtdeclarative qt6.qtsvg qt6.qtwayland kdePackages.layer-shell-qt ];
  dontWrapQtApps = true;
  doCheck = true;
  checkPhase = ''
    export PYTHONPATH="$PWD:${../tray-support}"
    export QT_QPA_PLATFORM=offscreen
    export XDG_CACHE_HOME="$TMPDIR/cache"
    ${python}/bin/python -B -m unittest discover -s tests -p 'test_*.py'
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/monitor-control" "$out/bin" "$out/share/icons/hicolor/scalable/apps"
    cp -r monitor_control "$out/lib/monitor-control/"
    cp ${../tray-support/tray_icon.py} "$out/lib/monitor-control/tray_icon.py"
    cp monitor_control/monitor.svg "$out/share/icons/hicolor/scalable/apps/monitor-control.svg"
    for entry in cli controller; do
      name=monitor-control
      if [ "$entry" = controller ]; then name=monitor-control-daemon; fi
      makeWrapper ${python}/bin/python "$out/bin/$name" \
        --add-flags "-m monitor_control.$entry" \
        --prefix PYTHONPATH : "$out/lib/monitor-control" \
        --set PYTHONDONTWRITEBYTECODE 1 \
        --prefix PATH : ${lib.makeBinPath [ systemd ]}
    done
    wrapQtApp "$out/bin/monitor-control-daemon" \
      --set QT_QPA_PLATFORM wayland \
      --prefix QML_IMPORT_PATH : "${kdePackages.layer-shell-qt}/lib/qt-6/qml"
    runHook postInstall
  '';
  meta.mainProgram = "monitor-control";
}
