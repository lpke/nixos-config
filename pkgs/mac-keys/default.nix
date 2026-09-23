{ lib, stdenvNoCC, python3, makeWrapper, qt6, openssh, systemd, ydotool, kdePackages }:
let
  python = python3.withPackages (ps: [ ps.pyqt6 ]);
in
stdenvNoCC.mkDerivation {
  pname = "mac-keys";
  version = "1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper qt6.wrapQtAppsHook ];
  buildInputs = [ qt6.qtbase qt6.qtsvg qt6.qtwayland ];
  dontWrapQtApps = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/mac-keys" "$out/bin"
    cp -r mac_keys icons mac-frontmost.js "$out/lib/mac-keys/"
    for entry in cli controller tray; do
      name="mac-keys-$entry"
      if [ "$entry" = cli ]; then name=mac-keys; fi
      makeWrapper ${python}/bin/python "$out/bin/$name" \
        --add-flags "-m mac_keys.$entry" \
        --prefix PYTHONPATH : "$out/lib/mac-keys" \
        --set PYTHONDONTWRITEBYTECODE 1 \
        --prefix PATH : ${lib.makeBinPath [ openssh systemd ydotool kdePackages.konsole ]}
    done
    wrapQtApp "$out/bin/mac-keys-tray"
    runHook postInstall
  '';
}
