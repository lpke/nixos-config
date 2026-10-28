let
  legacy = import ./mac-legacy.nix;
  backend = import ./backend.nix;
  # Mirrored from dotfiles/dot_hammerspoon/synergy-keymap.json; keep byte-identical.
  protocol = builtins.fromJSON (builtins.readFile ./synergy-keymap.json);
  remoteModes = [ "mac" "mac-super-left" "mac-super-right"
    "synergy-terminal" "synergy-terminal-super-left" "synergy-terminal-super-right" ];
  contextualNames = [ "Synergy thumb+L pilot" "Synergy terminal shortcuts" "mac shortcuts" ];
  relay = {
    name = "Synergy Mac-local app shortcuts";
    mode = remoteModes;
    device.not = [ "Logitech G903" ];
    exact_match = true;
    remap = builtins.listToAttrs (map (binding: {
      name = binding.input;
      value = binding.relay;
    }) protocol.bindings);
  };
in
assert protocol.version == 1;
assert builtins.elem backend [ "mac" "ssh" ];
if backend == "ssh" then legacy else legacy // {
  keymap = [ relay ]
    ++ builtins.filter (binding: !(builtins.elem binding.name contextualNames)) legacy.keymap
    ++ [{
      name = "Synergy app-independent shortcuts";
      mode = remoteModes;
      device.not = [ "Logitech G903" ];
      exact_match = true;
      remap."SUPER-space" = "C-space";
    }];
}
