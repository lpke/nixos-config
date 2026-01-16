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
      #   right-front: Button 5/BTN_FORWARD, right-back: Button 6/BTN_BACK
      #   wheel-left: Button 7/BTN_TASK, wheel-right: F23/KEY_F23

      # for key-to-key remaps (no combos/sequences)
      modmap = [
        # MOUSE
        # {
        #   name = "G903 Alacritty";
        #   device = {
        #     only = [ "Logitech G903" ];
        #   };
        #   application = {
        #     only = [ "/Alacritty/" ];
        #   };
        #   remap = {
        #     "BTN_EXTRA" = { # left front (double fix)
        #       held = "1";
        #       alone = [];
        #       alone_timeout_millis = 20;
        #     };
        #     "BTN_SIDE" = "2"; # left back
        #     "BTN_FORWARD" = "3"; # right front
        #     "BTN_BACK" = "4"; # right back
        #   };
        # }
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
            "BTN_BACK" = []; # right back - disabled
          };
        }
      ];

      # for anything with sequences
      keymap = [
        # MOUSE
        {
          name = "G903 Default";
          device = {
            only = [ "Logitech G903" ];
          };
          remap = {
            "BTN_FORWARD" = "SUPER-w"; # right front - overview
            # "BTN_BACK" = []; # right back (actively disabed in "modmap" section)
            "BTN_TASK" = "C-SUPER-left"; # wheel-left - desktop left
            "KEY_F23" = "C-SUPER-right"; # wheel-right - desktop right
          };
        }

        # KEYBOARD
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
