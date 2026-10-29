let
  modesFor = base: [ base "${base}-super-left" "${base}-super-right" ];
  macModes = modesFor "mac";
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
  mouseGesture = button: before: after: {
    skip_key_event = true;
    press = before ++ [
      { press = "CTRL_L"; }
      { press = button; }
    ];
    release = [
      { release = button; }
      { release = "CTRL_L"; }
    ] ++ after;
  };
in
{
  modeSwitchInternalKeymap = [
    {
      name = "Internal mode switch with held Super";
      device.only = [ "ydotoold virtual device" ];
      # Match held modifiers before the unconditional mode-switch keymap.
      remap = {
        "SUPER_L-KEY_F24".set_mode = "mac-super-left";
        "SUPER_R-KEY_F24".set_mode = "mac-super-right";
      };
    }
    {
      name = "Internal mode switch";
      device.only = [ "ydotoold virtual device" ];
      remap = {
        "KEY_F22".set_mode = "local";
        "KEY_F24".set_mode = "mac";
      };
    }
  ];

  modmap = builtins.concatMap (base: [
    {
      name = "mac Super state";
      mode = modesFor base;
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
      name = "mac window move";
      mode = [ "${base}-super-left" "${base}-super-right" ];
      # macOS native window movement uses Command+Control+left drag.
      remap."BTN_LEFT" = mouseGesture "BTN_LEFT" [] [];
    }
  ] ++ map (super: {
    name = "mac window resize with ${super.key}";
    mode = "${base}-super-${super.side}";
    # The live Easy Move+Resize setup is Control-only and resize-only.
    # Restore Command on release so another gesture can use the held Super key.
    remap."BTN_RIGHT" = mouseGesture "BTN_RIGHT"
      [ { release = super.key; } ] [ { press = super.key; } ];
  }) [
    { side = "left"; key = "SUPER_L"; }
    { side = "right"; key = "SUPER_R"; }
  ]) [ "mac" ];

  # Add only shortcuts that should differ while controlling macOS.
  keymap = [
    {
      name = "Synergy Mac actions";
      mode = macModes;
      device.not = [ "Logitech G903" ];
      exact_match = true;
      # Synergy bypasses Karabiner; Hammerspoon handles these Mac actions.
      remap = {
        "SUPER-m" = "C-ALT-SHIFT-SUPER_R-m";
        "SUPER-n" = "C-ALT-SHIFT-SUPER_R-n";
        "C-delete" = "SUPER_R-delete";
      };
    }

    {
      name = "Synergy directional window focus";
      mode = macModes;
      device.not = [ "Logitech G903" ];
      exact_match = true;
      # Synergy bypasses Karabiner and its Mac client drops F17-F20. Use
      # Hammerspoon's Hyper+F13-F16 relay for Linux-layer Super+H/J/K/L.
      # Keep Ctrl shortcuts available to apps; native Mac Control is a different layer.
      remap = {
        "SUPER-h" = "C-ALT-SHIFT-SUPER_R-F13";
        "SUPER-j" = "C-ALT-SHIFT-SUPER_R-F14";
        "SUPER-k" = "C-ALT-SHIFT-SUPER_R-F15";
        "SUPER-l" = "C-ALT-SHIFT-SUPER_R-F16";
      };
    }

    {
      name = "Synergy window growth";
      mode = macModes;
      device.not = [ "Logitech G903" ];
      exact_match = true;
      # Linux pinky+Alt+V/B matches native Mac Control+Alt+V/B.
      remap = {
        "SUPER-ALT-v" = "C-ALT-SHIFT-SUPER_R-F9";
        "SUPER-ALT-b" = "C-ALT-SHIFT-SUPER_R-F10";
      };
    }

    {
      name = "Synergy hovered window stacking";
      mode = macModes;
      exact_match = true;
      # Keyboard relays preserve the Mac's existing hovered-window/burst logic.
      # Handle both wheel streams; repeated relays keep the same burst target.
      remap = {
        "SUPER-XUPSCROLL" = "C-ALT-SHIFT-SUPER_R-F11";
        "SUPER-XDOWNSCROLL" = "C-ALT-SHIFT-SUPER_R-F12";
        "SUPER-XHIRES_UPSCROLL" = "C-ALT-SHIFT-SUPER_R-F11";
        "SUPER-XHIRES_DOWNSCROLL" = "C-ALT-SHIFT-SUPER_R-F12";
      };
    }

    {
      name = "mac mouse shortcuts";
      mode = macModes;
      device.only = [ "Logitech G903" ];
      remap = {
        "BTN_FORWARD" = synergyHyper "k"; # right front: Mission Control
        "BTN_TASK" = synergyHyper "h"; # wheel left: desktop left
        "KEY_F23" = synergyHyper "l"; # wheel right: desktop right
      };
    }

    {
      name = "Synergy app-independent shortcuts";
      mode = macModes;
      device.not = [ "Logitech G903" ];
      exact_match = true;
      # Spotlight uses Command+Space; right Command avoids terminal modifier remaps.
      remap = {
        "SUPER-space" = "SUPER_R-space";
        # Moonlander bottom-left Enter/hold key sends Alt+Shift+Super on Linux.
        # Match its native Mac Ctrl+Option+Shift screenshot chord.
        "SHIFT-ALT-SUPER-s" = "C-ALT-SHIFT-s";
      };
    }
  ];
}
