{
  # for key-to-key remaps (no combos/sequences)
  modmap = [];

  # for anything with sequences
  keymap = [
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
}
