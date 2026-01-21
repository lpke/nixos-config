{
  # Logitech G903 buttons (piper setting / xremap value):
  #   left-front: Forward/BTN_EXTRA | left-back: Backward/BTN_SIDE
  #   right-front: Button 5/BTN_FORWARD, right-back: ctrl+m/C-m
  #   wheel-left: Button 7/BTN_TASK, wheel-right: F23/KEY_F23

  # for key-to-key remaps (no combos/sequences)
  modmap = [
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
  ];
}
