{ lib, stdenvNoCC, python3, makeWrapper, qt6, systemd, tailscale, xdg-utils, kdePackages }:
let
  python = python3.withPackages (ps: [ ps.pyqt6 ]);
in
stdenvNoCC.mkDerivation {
  pname = "t3-tailscale";
  version = "1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper qt6.wrapQtAppsHook ];
  buildInputs = [ qt6.qtbase qt6.qtsvg qt6.qtwayland ];
  dontWrapQtApps = true;
  doInstallCheck = true;
  installCheckPhase = ''
    PYTHONPATH="$out/lib/t3-tailscale" ${python}/bin/python -B -c "from t3_tailscale.tray import Tray; import t3_connection_tray"
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/t3-tailscale" "$out/bin"
    cp -r t3_tailscale icons help.txt "$out/lib/t3-tailscale/"
    cp ${../t3-connection-tray/t3_connection_tray.py} "$out/lib/t3-tailscale/t3_connection_tray.py"
    for entry in cli tray; do
      name="t3-tailscale-$entry"
      if [ "$entry" = cli ]; then name=t3-tailscale; fi
      makeWrapper ${python}/bin/python "$out/bin/$name" \
        --add-flags "-m t3_tailscale.$entry" \
        --prefix PYTHONPATH : "$out/lib/t3-tailscale" \
        --set PYTHONDONTWRITEBYTECODE 1 \
        --prefix PATH : "$out/bin" \
        --prefix PATH : ${lib.makeBinPath [ systemd tailscale xdg-utils kdePackages.konsole ]}
    done
    wrapQtApp "$out/bin/t3-tailscale-tray"
    runHook postInstall
  '';
}
