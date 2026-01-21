let
  mouse = import ./mouse.nix;
  keyboard = import ./keyboard.nix;
in
{
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
      modmap = mouse.modmap ++ keyboard.modmap;
      keymap = mouse.keymap ++ keyboard.keymap;
    };
  };
}
