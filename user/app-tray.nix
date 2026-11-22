{ pkgs, ... }:
let tray = pkgs.callPackage ../pkgs/app-tray {};
in {
  home.file.".local/bin/app-tray-daemon".source = "${tray}/bin/app-tray-daemon";
}
