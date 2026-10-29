# Evaluate the same rules as xremap, preserving their order and source locations.
let
  mac = import ../../user/xremap/mac.nix;
  mouse = import ../../user/xremap/mouse.nix;
  keyboard = import ../../user/xremap/keyboard.nix;
  tag = source: rules: map (rule: rule // { inspect_source = source; }) rules;
in {
  protocol = builtins.fromJSON (builtins.readFile ../../user/xremap/synergy-keymap.json);
  modmap = tag "user/xremap/mac-common.nix" mac.modmap
    ++ tag "user/xremap/mouse.nix" mouse.modmap
    ++ tag "user/xremap/keyboard.nix" keyboard.modmap;
  keymap = tag "user/xremap/mac-common.nix" mac.modeSwitchInternalKeymap
    ++ tag "user/xremap/mac.nix" [ (builtins.head mac.keymap) ]
    ++ tag "user/xremap/mac-common.nix" (builtins.tail mac.keymap)
    ++ tag "user/xremap/mouse.nix" mouse.keymap
    ++ tag "user/xremap/keyboard.nix" keyboard.keymap;
}
