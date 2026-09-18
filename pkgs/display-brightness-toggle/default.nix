{ pkgs }:

pkgs.writeShellApplication {
  name = "display-brightness-toggle";
  runtimeInputs = with pkgs; [ kdePackages.libkscreen jq util-linux systemd coreutils ];
  text = builtins.replaceStrings
    [ "@qml@" "@layerShellImports@" "@blackoutQml@" ]
    [
      "${pkgs.kdePackages.qtdeclarative}/bin/qml"
      "${pkgs.kdePackages.layer-shell-qt}/lib/qt-6/qml"
      "${./blackout.qml}"
    ]
    (builtins.readFile ./display-brightness-toggle.sh);
}
