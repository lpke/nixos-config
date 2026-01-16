{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.xremap-flake.homeManagerModules.default
  ];

  home.stateVersion = "25.11";
  home.username = "luke";
  home.homeDirectory = "/home/luke";
  home.packages = [
    # enables running `xremap` as a command
    inputs.xremap-flake.packages.${pkgs.system}.default
  ];
  programs.home-manager.enable = true;

  services.xremap = {
    enable = true;
    withKDE = true;

    # enable full detail xremap logging with:
    # journalctl --user -u xremap.service -f
    debug = false;

    # deviceNames = [ # only include keyboard, leave mouse alone
    #   "ZSA Technology Labs Moonlander Mark I"
    #   "ZSA Technology Labs Moonlander Mark I Keyboard"
    # ];

    # higher items override lower ones
    # put default/generic remaps lower than app overrides
    config = {
      # Logitech G903 buttons (piper setting / xremap value):
      #   left-front: Forward/BTN_EXTRA | left-back: Backward/BTN_SIDE
      #   right-front: Button 5/BTN_FORWARD, right-back: ctrl+m/C-m
      #   wheel-left: Button 7/BTN_TASK, wheel-right: F23/KEY_F23

      # for key-to-key remaps (no combos/sequences)
      modmap = [
        # MOUSE
        {
          name = "G903 Minecraft";
          device = {
            only = [ "Logitech G903" ];
          };
          application = {
            only = [ "/Minecraft/" ];
          };
          remap = {
            "BTN_EXTRA" = "w"; # left front - walk forward
            "BTN_SIDE" = "s"; # left back - walk backward
            "BTN_FORWARD" = "KEY_F5"; # right front - third person
          };
        }
        {
          name = "G903 Runelite";
          device = {
            only = [ "Logitech G903" ];
          };
          application = {
            only = [ "/runelite/" ];
          };
          remap = {
            "BTN_EXTRA" = { # left front - space (double fix)
              held = "SPACE";
              alone = [];
              alone_timeout_millis = 20;
            };
            "BTN_SIDE" = "ESC"; # left back - esc
            "BTN_FORWARD" = "BTN_MIDDLE"; # right front - middle mouse
          };
        }
        {
          name = "G903 Default";
          device = {
            only = [ "Logitech G903" ];
          };
          remap = {
            "BTN_EXTRA" = { # left front - forward (double fix)
              held = "BTN_EXTRA";
              alone = [];
              alone_timeout_millis = 20;
            };
            "BTN_SIDE" = "BTN_SIDE"; # left back - backward
          };
        }
      ];

      # for anything with sequences
      keymap = [
        # MOUSE
        {
          name = "G903 Default - right back";
          device = {
            only = [ "Logitech G903" ];
          };
          application = {
            not = [ "/runelite/" ];
          };
          remap = {
            "C-m" = "KEY_RESERVED"; # right back - disabled
          };
        }
        {
          name = "G903 Default";
          device = {
            only = [ "Logitech G903" ];
          };
          remap = {
            "BTN_FORWARD" = "SUPER-w"; # right front - overview
            "BTN_TASK" = "C-SUPER-left"; # wheel-left - desktop left
            "KEY_F23" = "C-SUPER-right"; # wheel-right - desktop right
          };
        }

        # KEYBOARD
        {
          name = "Runelite";
          device = {
            not = [ "Logitech G903" ];
          };
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
