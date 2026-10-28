{ lib, stdenvNoCC, python3, makeWrapper, qt6, systemd, ydotool, kdePackages }:
let
  python = python3.withPackages (ps: [ ps.pyqt6 ]);
in
stdenvNoCC.mkDerivation {
  pname = "synergy-keys";
  version = "1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper qt6.wrapQtAppsHook ];
  buildInputs = [ qt6.qtbase qt6.qtsvg qt6.qtwayland ];
  dontWrapQtApps = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/synergy-keys" "$out/bin"
    cp -r synergy_keys icons "$out/lib/synergy-keys/"
    for entry in cli controller tray; do
      name="synergy-keys-$entry"
      if [ "$entry" = cli ]; then name=synergy-keys; fi
      makeWrapper ${python}/bin/python "$out/bin/$name" \
        --add-flags "-m synergy_keys.$entry" \
        --prefix PYTHONPATH : "$out/lib/synergy-keys" \
        --set PYTHONDONTWRITEBYTECODE 1 \
        --prefix PATH : ${lib.makeBinPath [ systemd ydotool kdePackages.konsole ]}
    done
    wrapQtApp "$out/bin/synergy-keys-tray"
    runHook postInstall
  '';
}
