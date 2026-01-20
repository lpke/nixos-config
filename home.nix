{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.xremap-flake.homeManagerModules.default
    ./xremap.nix
  ];

  home.stateVersion = "25.11";
  home.username = "luke";
  home.homeDirectory = "/home/luke";
  home.packages = [
    # enables running `xremap` as a command
    inputs.xremap-flake.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
  programs.home-manager.enable = true;
}
