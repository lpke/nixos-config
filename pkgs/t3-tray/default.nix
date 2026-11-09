{ lib, stdenvNoCC, python3, makeWrapper, qt6, systemd, alacritty, callPackage }:
let
  python = python3.withPackages (ps: [ ps.pyqt6 ]);
  ssh = callPackage ../t3-ssh {};
  tailscale = callPackage ../t3-tailscale {};
in
stdenvNoCC.mkDerivation {
  pname = "t3-tray";
  version = "1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper qt6.wrapQtAppsHook ];
  buildInputs = [ qt6.qtbase qt6.qtsvg qt6.qtwayland ];
  dontWrapQtApps = true;
  doInstallCheck = true;
  installCheckPhase = ''
    PYTHONPATH="$out/lib/t3-tray" ${python}/bin/python -B -c "from t3_tray.tray import Tray; from tray_icon import svg_icon"
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/t3-tray" "$out/bin"
    cp -r t3_tray LICENSE-T3 "$out/lib/t3-tray/"
    cp ${../tray-support/tray_icon.py} "$out/lib/t3-tray/tray_icon.py"
    mkdir -p "$out/share/icons/hicolor/scalable/apps"
    PYTHONPATH="$out/lib/t3-tray" ${python}/bin/python -B -c \
      'from t3_tray.icons import app_icon_svg; print(app_icon_svg())' \
      > "$out/share/icons/hicolor/scalable/apps/t3-controls.svg"
    for entry in cli tray; do
      name=t3-tray
      if [ "$entry" = tray ]; then name=t3-tray-daemon; fi
      makeWrapper ${python}/bin/python "$out/bin/$name" \
        --add-flags "-m t3_tray.$entry" \
        --prefix PYTHONPATH : "$out/lib/t3-tray" \
        --prefix PATH : "$out/bin" \
        --set PYTHONDONTWRITEBYTECODE 1 \
        --prefix PATH : ${lib.makeBinPath [ ssh tailscale systemd alacritty ]}
    done
    wrapQtApp "$out/bin/t3-tray-daemon"
    runHook postInstall
  '';
}
