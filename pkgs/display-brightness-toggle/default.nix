{ pkgs }:

pkgs.writeShellApplication {
  name = "display-brightness-toggle";
  runtimeInputs = [ (pkgs.callPackage ../monitor-control {}) ];
  text = builtins.readFile ./display-brightness-toggle.sh;
}
