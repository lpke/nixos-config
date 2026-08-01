# ══════════════════════════════════════════════════════════════════
# XREMAP
# ══════════════════════════════════════════════════════════════════
let
  mouse = import ./mouse.nix;
  keyboard = import ./keyboard.nix;
  mac = import ./mac.nix;
in
{
  # deviceNames = [ # only include keyboard, leave mouse alone
  #   "ZSA Technology Labs Moonlander Mark I"
  #   "ZSA Technology Labs Moonlander Mark I Keyboard"
  # ];

  # higher items override lower ones
  # put default/generic remaps lower than app overrides
  config = {
    default_mode = "local";
    modmap = mouse.modmap ++ keyboard.modmap;
    keymap = mac.modeSwitchInternalKeymap ++ mac.keymap ++ mouse.keymap ++ keyboard.keymap;
  };
}
