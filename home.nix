{ config, pkgs, ... }:

{
  home.stateVersion = "25.11";
  home.username = "luke";
  home.packages = [ ];
  programs.home-manager.enable = true;

  programs.neovim = {
    enable = true;
    extraPackages = with pkgs; [
      fzf
      nodejs_24
      ripgrep
    ];
  };
}
