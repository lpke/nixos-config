{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.xremap-flake.homeManagerModules.default
  ];

  home.stateVersion = "25.11";
  home.username = "luke";
  home.homeDirectory = "/home/luke";
  home.packages = [ ];
  programs.home-manager.enable = true;

  services.xremap = {
    enable = true;
    withKDE = true;
    deviceNames = [ # only include keyboard, leave mouse alone
      "ZSA Technology Labs Moonlander Mark I"
      "ZSA Technology Labs Moonlander Mark I Keyboard"
    ];
    config = {
      keymap = [
        # {
        #   name = "Test remap";
        #   remap = {
        #     "KEY_RIGHTALT-KEY_P" = "KEY_O";
        #   };
        # }
        {
          name = "Runelite remaps";
          application = {
            only = [ "/runelite/" ];
          };
          remap = {
            "C-a" = "1";
            "C-s" = "2";
            "C-d" = "3";
            "C-f" = "4";
            "C-g" = "5";
            "C-q" = "6";
            "C-w" = "7";
            "C-e" = "8";
            "C-r" = "9";
            "C-t" = "0";
          };
        }
      ];
    };
  };
}
