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

  # Add only shortcuts that should differ while controlling macOS.
  keymap = [
    {
      name = "mac: example shortcuts";
      mode = "mac";
      device.not = [ "Logitech G903" ];
      remap = {
        "C-c" = "SUPER-c";
        "C-v" = "SUPER-v";
        "SUPER-space" = "C-space";
      };
    }
  ];
}
