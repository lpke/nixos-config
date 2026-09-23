let
  synergyHyper = key: [
    { press = "CTRL_L"; }
    { press = "ALT_L"; }
    { press = "SHIFT_L"; }
    { press = "SUPER_L"; }
    { sleep = 10; }
    { press = key; }
    { release = key; }
    { sleep = 10; }
    { release = "SUPER_L"; }
    { release = "SHIFT_L"; }
    { release = "ALT_L"; }
    { release = "CTRL_L"; }
  ];
in
{
  modeSwitchInternalKeymap = [
    {
      name = "Internal mode switch";
      device.only = [ "ydotoold virtual device" ];
      remap = {
        "KEY_F22".set_mode = "local";
        "KEY_F24".set_mode = "mac";
        "KEY_F21".set_mode = "synergy-terminal";
      };
    }
  ];

  modmap = builtins.concatMap (base: [
    {
      name = "mac Super state";
      mode = [ base "${base}-super-left" "${base}-super-right" ];
      remap = {
        "SUPER_L" = {
          press.set_mode = "${base}-super-left";
          release.set_mode = base;
        };
        "SUPER_R" = {
          press.set_mode = "${base}-super-right";
          release.set_mode = base;
        };
      };
    }

    {
      name = "mac window drag";
      mode = [ "${base}-super-left" "${base}-super-right" ];
      remap = {
        "BTN_LEFT" = {
          skip_key_event = true;
          press = [
            { press = "CTRL_L"; }
            { press = "BTN_LEFT"; }
          ];
          release = [
            { release = "BTN_LEFT"; }
            { release = "CTRL_L"; }
          ];
        };
      };
    }

    {
      name = "mac right-button drag with left Super";
      mode = "${base}-super-left";
      remap."BTN_RIGHT" = {
        skip_key_event = true;
        press = [
          { release = "SUPER_L"; }
          { press = "CTRL_L"; }
          { press = "BTN_RIGHT"; }
        ];
        release = [
          { release = "BTN_RIGHT"; }
          { release = "CTRL_L"; }
          { press = "SUPER_L"; }
        ];
      };
    }

    {
      name = "mac right-button drag with right Super";
      mode = "${base}-super-right";
      remap."BTN_RIGHT" = {
        skip_key_event = true;
        press = [
          { release = "SUPER_R"; }
          { press = "CTRL_L"; }
          { press = "BTN_RIGHT"; }
        ];
        release = [
          { release = "BTN_RIGHT"; }
          { release = "CTRL_L"; }
          { press = "SUPER_R"; }
        ];
      };
    }
  ]) [ "mac" "synergy-terminal" ];

  # Add only shortcuts that should differ while controlling macOS.
  keymap = [
    {
      name = "mac mouse shortcuts";
      mode = [ "mac" "mac-super-left" "mac-super-right"
        "synergy-terminal" "synergy-terminal-super-left" "synergy-terminal-super-right" ];
      device.only = [ "Logitech G903" ];
      remap = {
        "BTN_FORWARD" = synergyHyper "k"; # right front: Mission Control
        "BTN_TASK" = synergyHyper "h"; # wheel left: desktop left
        "KEY_F23" = synergyHyper "l"; # wheel right: desktop right
      };
    }

    {
      name = "Synergy terminal shortcuts";
      mode = [ "synergy-terminal" "synergy-terminal-super-left" "synergy-terminal-super-right" ];
      device.not = [ "Logitech G903" ];
      # Identity mappings stop the PC's focused app rules from handling these
      # keys while Alacritty or iTerm has focus on the Mac. Keep native Ctrl bindings.
      remap = builtins.listToAttrs (map (key: { name = key; value = key; }) (
        (builtins.concatMap (key: [ "C-${key}" "C-SHIFT-${key}" ]) [
          "a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m"
          "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z"
          "left" "right" "up" "down" "backspace" "delete" "enter"
        ]) ++ [ "HOME" "END" "SHIFT-HOME" "SHIFT-END" ]
      )) // {
        # iTerm also remaps left Command to Control internally. Right Command
        # keeps these application actions intact without changing that setting.
        "C-SHIFT-c" = "SUPER_R-c"; # terminal copy; Ctrl+C remains interrupt
        "C-SHIFT-v" = "SUPER_R-v"; # terminal paste
        "C-backspace" = "C-w"; # delete a word in both Mac terminals
        # iTerm consumes Ctrl+Shift+Down. Both Mac terminal profiles decode
        # this reserved Synergy chord as CSI 1;6B, without native key changes.
        "C-SHIFT-down" = "C-ALT-SHIFT-SUPER_R-y";
        "SUPER-space" = "C-space"; # retain the existing Spotlight shortcut
      };
    }

    {
      name = "mac shortcuts";
      mode = [ "mac" "mac-super-left" "mac-super-right" ];
      device.not = [ "Logitech G903" ];
      remap = {
        "C-c" = "SUPER-c";
        "C-x" = "SUPER-x";
        "C-v" = "SUPER-v";
        "C-z" = "SUPER-z";
        "C-S-z" = "SUPER-S-z";
        "SUPER-space" = "C-space";
        "C-a" = "SUPER-a";
        "C-f" = "SUPER-f";
        "C-r" = "SUPER-r";
        "C-t" = "SUPER-t";
        "C-w" = "SUPER-w";
        "C-enter" = "SUPER-enter";

        # word/line navigation
        "C-left" = "ALT-left";
        "C-right" = "ALT-right";
        "C-S-left" = "ALT-S-left";
        "C-S-right" = "ALT-S-right";
        "C-backspace" = "ALT-backspace";
        "C-delete" = "ALT-delete";
        "HOME" = "SUPER-left";
        "END" = "SUPER-right";
        "S-HOME" = "SUPER-S-left";
        "S-END" = "SUPER-S-right";
      };
    }
  ];
}
