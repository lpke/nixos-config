{ lib, stdenvNoCC, python3, makeWrapper, qt6, systemd, xdg-utils, kdePackages }:
let
  python = python3.withPackages (ps: [ ps.pyqt6 ]);
in
stdenvNoCC.mkDerivation {
  pname = "t3-ssh";
  version = "1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper qt6.wrapQtAppsHook ];
  buildInputs = [ qt6.qtbase qt6.qtsvg qt6.qtwayland ];
  dontWrapQtApps = true;
  doInstallCheck = true;
  installCheckPhase = ''
    PYTHONPATH="$out/lib/t3-ssh" ${python}/bin/python -B -c "from t3_ssh.tray import Tray; import t3_connection_tray"
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/t3-ssh" "$out/bin"
    cp -r t3_ssh icons help.txt "$out/lib/t3-ssh/"
    cp ${../t3-connection-tray/t3_connection_tray.py} "$out/lib/t3-ssh/t3_connection_tray.py"
    for entry in cli tray; do
      name="t3-ssh-$entry"
      if [ "$entry" = cli ]; then name=t3-ssh; fi
      makeWrapper ${python}/bin/python "$out/bin/$name" \
        --add-flags "-m t3_ssh.$entry" \
        --prefix PYTHONPATH : "$out/lib/t3-ssh" \
        --set PYTHONDONTWRITEBYTECODE 1 \
        --prefix PATH : "$out/bin" \
        --prefix PATH : ${lib.makeBinPath [ systemd xdg-utils kdePackages.konsole ]}
    done
    wrapQtApp "$out/bin/t3-ssh-tray"
    runHook postInstall
  '';
}
