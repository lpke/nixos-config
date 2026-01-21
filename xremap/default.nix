let
  mouse = import ./mouse.nix;
  keyboard = import ./keyboard.nix;
in
  {
  # deviceNames = [ # only include keyboard, leave mouse alone
  #   "ZSA Technology Labs Moonlander Mark I"
  #   "ZSA Technology Labs Moonlander Mark I Keyboard"
  # ];

  # higher items override lower ones
  # put default/generic remaps lower than app overrides
  config = {
    modmap = mouse.modmap ++ keyboard.modmap;
    keymap = mouse.keymap ++ keyboard.keymap;
  };
}
