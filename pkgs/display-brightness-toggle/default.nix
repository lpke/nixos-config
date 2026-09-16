{ pkgs }:

pkgs.writeShellApplication {
  name = "display-brightness-toggle";
  runtimeInputs = with pkgs; [ kdePackages.libkscreen jq util-linux ];
  text = builtins.readFile ./display-brightness-toggle.sh;
}
