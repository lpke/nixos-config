let
  common = import ./mac-common.nix;
  # Mirrored from dotfiles/dot_hammerspoon/synergy-keymap.json; keep byte-identical.
  protocol = builtins.fromJSON (builtins.readFile ./synergy-keymap.json);
  relay = {
    name = "Synergy Mac-local app shortcuts";
    mode = [ "mac" "mac-super-left" "mac-super-right" ];
    device.not = [ "Logitech G903" ];
    exact_match = true;
    remap = builtins.listToAttrs (map (binding: {
      name = binding.input;
      value = binding.relay;
    }) protocol.bindings);
  };
in
assert protocol.version == 1;
common // { keymap = [ relay ] ++ common.keymap; }
