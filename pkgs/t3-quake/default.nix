{ lib, stdenvNoCC, python3, makeWrapper, qt6, systemd, libnotify, nodejs }:
let
  python = python3.withPackages (ps: [ ps.pyqt6 ]);
in
stdenvNoCC.mkDerivation {
  pname = "t3-quake";
  version = "1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper qt6.wrapQtAppsHook nodejs ];
  buildInputs = [ qt6.qtbase qt6.qtwayland ];
  dontWrapQtApps = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    node --test tests/controller.test.cjs tests/effect.test.cjs
    QT_QPA_PLATFORM=offscreen PYTHONPATH="$PWD" ${python}/bin/python -B -m unittest discover -s tests -p 'test_*.py'
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/t3-quake" "$out/bin" "$out/share/kwin/scripts" "$out/share/kwin/effects"
    cp -r t3_quake "$out/lib/t3-quake/"
    cp -r kwin "$out/share/kwin/scripts/t3-quake"
    cp -r effect "$out/share/kwin/effects/t3-quake-slide"
    cp error.sh "$out/bin/t3-quake-error"
    chmod +x "$out/bin/t3-quake-error"
    substituteInPlace "$out/bin/t3-quake-error" --replace-fail 'exec notify-send' 'exec ${libnotify}/bin/notify-send'
    patchShebangs "$out/bin/t3-quake-error"
    for entry in cli daemon; do
      name=t3-quake
      if [ "$entry" = daemon ]; then name=t3-quake-daemon; fi
      makeWrapper ${python}/bin/python "$out/bin/$name" \
        --add-flags "-m t3_quake.$entry" \
        --prefix PYTHONPATH : "$out/lib/t3-quake" \
        --set PYTHONDONTWRITEBYTECODE 1 \
        --prefix PATH : ${lib.makeBinPath [ systemd libnotify ]}
    done
    wrapQtApp "$out/bin/t3-quake-daemon" --set QT_QPA_PLATFORM wayland
    runHook postInstall
  '';
  meta.mainProgram = "t3-quake";
}
