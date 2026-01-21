{ config, pkgs, inputs, ... }:

# `flake.nix` outputs > modules > home-manager.users.luke...
{
  imports = [
    inputs.xremap-flake.homeManagerModules.default
    ./xremap
    ./plasma
  ];

  home.stateVersion = "25.11";
  home.username = "luke";
  home.homeDirectory = "/home/luke";
  home.packages = [
    # enables running `xremap` as a command
    inputs.xremap-flake.packages.${pkgs.stdenv.hostPlatform.system}.default
    # enables running `rc2nix` as a command
    inputs.plasma-manager.packages.${pkgs.stdenv.hostPlatform.system}.rc2nix
  ];

  programs.home-manager.enable = true;
  
  # enabling and settings of other modules are done from their imports
  # eg `./xremap/default.nix` has `services.xremap.enable = true;`
}
