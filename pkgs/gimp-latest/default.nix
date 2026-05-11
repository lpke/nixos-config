{
  lib,
  fetchurl,
  appimageTools,
}:

let
  pname = "gimp";
  version = "3.2.4";

  src = fetchurl {
    url = "https://download.gimp.org/gimp/v${lib.versions.majorMinor version}/linux/GIMP-${version}-x86_64.AppImage";
    hash = "sha256-8c5txnHvHEqth6DbnXRi6MqcC1+JlFYzeAPGujLQur4=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/org.gimp.GIMP.Stable.desktop \
      $out/share/applications/org.gimp.GIMP.Stable.desktop
    install -Dm444 ${appimageContents}/org.gimp.GIMP.Stable.svg \
      $out/share/icons/hicolor/scalable/apps/org.gimp.GIMP.Stable.svg

    substituteInPlace $out/share/applications/org.gimp.GIMP.Stable.desktop \
      --replace-fail "Exec=org.gimp.GIMP.Stable %U" "Exec=gimp %U"
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "GNU Image Manipulation Program, latest stable official AppImage";
    homepage = "https://www.gimp.org/";
    changelog = "https://www.gimp.org/news/";
    license = lib.licenses.gpl3Plus;
    mainProgram = "gimp";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
