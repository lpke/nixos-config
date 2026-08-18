{
  appimageTools,
  fetchurl,
  lib,
  version,
  hash,
}:

let
  pname = "t3code";

  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
    inherit hash;
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = pkgs: [ pkgs.libsecret ];

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/t3code.desktop \
      $out/share/applications/t3code.desktop
    cp -r ${appimageContents}/usr/share/icons $out/share/

    substituteInPlace $out/share/applications/t3code.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=t3code %U'
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Minimal web GUI for coding agents";
    homepage = "https://t3.codes/";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "t3code";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
