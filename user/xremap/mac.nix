{
  modeSwitchInternalKeymap = [
    {
      name = "Internal mode switch";
      device.only = [ "ydotoold virtual device" ];
      remap = {
        "KEY_F22".set_mode = "local";
        "KEY_F24".set_mode = "mac";
      };
    }
  ];

  modmap = [
    {
      name = "mac Super state";
      mode = [ "mac" "mac-super-left" "mac-super-right" ];
      remap = {
        "SUPER_L" = {
          press.set_mode = "mac-super-left";
          release.set_mode = "mac";
        };
        "SUPER_R" = {
          press.set_mode = "mac-super-right";
          release.set_mode = "mac";
        };
      };
    }

    {
      name = "mac window drag";
      mode = [ "mac-super-left" "mac-super-right" ];
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
      mode = "mac-super-left";
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
      mode = "mac-super-right";
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
  ];

  # Add only shortcuts that should differ while controlling macOS.
  keymap = [
    {
      name = "mac mouse shortcuts";
      mode = [ "mac" "mac-super-left" "mac-super-right" ];
      device.only = [ "Logitech G903" ];
      remap = {
        "BTN_FORWARD" = "C-ALT-S-SUPER-k"; # right front: Mission Control
        "BTN_TASK" = "C-ALT-S-SUPER-h"; # wheel left: desktop left
        "KEY_F23" = "C-ALT-S-SUPER-l"; # wheel right: desktop right
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
        "C-w" = "SUPER-w";

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
