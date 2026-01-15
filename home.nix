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
        {
          name = "Test remap";
          remap = {
            "KEY_RIGHTALT-KEY_P" = "KEY_O";
          };
        }
      ];
    };
  };
}
