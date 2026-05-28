{ lib, ... }:

{
  # Local extensions to upstream NixOS module options.
  options.programs._1password-gui.autoLockMins = lib.mkOption {
    type = lib.types.nullOr lib.types.ints.positive;
    default = null;
    description = ''
      Lock 1Password via Plasma PowerDevil after this many minutes of desktop
      idle time. Set to null to disable the local workaround.
    '';
  };
}
