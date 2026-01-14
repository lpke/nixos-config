{ config, pkgs, ... }:

{
  home.stateVersion = "25.11";
  home.username = "luke";
  home.packages = [ ];
  programs.home-manager.enable = true;
}
