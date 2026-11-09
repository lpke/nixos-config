{ pkgs, ... }:
let tray = pkgs.callPackage ../pkgs/html-tray {};
in {
  home.file.".local/bin/html-tray-daemon".source = "${tray}/bin/html-tray-daemon";
}
