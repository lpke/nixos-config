{ pkgs }:

let
  launchInputs = with pkgs; [
    coreutils
    curl
    kdePackages.konsole
    wineWowPackages.waylandFull
  ];

  convertInputs = with pkgs; [
    coreutils
    curl
    exiftool
    jq
    wineWowPackages.waylandFull
  ];

  adobeDngConverter = pkgs.writeShellApplication {
    name = "adobe-dng-converter";
    runtimeInputs = launchInputs;
    text = builtins.readFile ./adobe-dng-converter.sh;
  };

  convertDng = pkgs.writeShellApplication {
    name = "convert-dng";
    runtimeInputs = convertInputs;
    text = builtins.readFile ./convert-dng.sh;
  };
in
pkgs.symlinkJoin {
  name = "adobe-dng-tools";
  paths = [
    adobeDngConverter
    convertDng
  ];
}
