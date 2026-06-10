{ config, lib, ... }:

let
  cfg = config.services.pipewire.audioVolumeLocks;
  devicesMap = config.services.pipewire.audioDevicesMap;

  rawPrefix = "RAW:";
  isRaw = value: lib.hasPrefix rawPrefix value;
  rawNode = value: lib.removePrefix rawPrefix value;

  enabledLocks = lib.filterAttrs (_: lock: lock.enable) cfg.locks;
  lockNodeNames = map (lock: lock.nodeName) (lib.attrValues enabledLocks);
  invalidRawTargets = lib.filter (value: isRaw value && rawNode value == "") lockNodeNames;
  missingDeviceNames = lib.filter (value: !(isRaw value) && !(builtins.hasAttr value devicesMap.pipewireNodes)) lockNodeNames;
in
{
  options.services.pipewire.audioVolumeLocks = {
    enable = lib.mkEnableOption "PipeWire volume locks";

    intervalSeconds = lib.mkOption {
      type = lib.types.str;
      default = "0.25";
      description = "Delay after audio change events before reapplying locks.";
    };

    service = lib.mkOption {
      type = lib.types.str;
      default = "audio-volume-locks.service";
      description = "User systemd service name for the PipeWire volume lock daemon.";
    };

    locks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable this lock.";
          };

          description = lib.mkOption {
            type = lib.types.str;
            default = name;
            description = "Human-readable lock label.";
          };

          nodeName = lib.mkOption {
            type = lib.types.str;
            description = "Friendly audioDevicesMap.pipewireNodes name, or RAW:<pipewire-node-name> for a raw PipeWire node.";
          };

          volume = lib.mkOption {
            type = lib.types.str;
            example = "1.00";
            description = "Volume to enforce. PipeWire uses 1.00 for 100%.";
          };
        };
      }));
      default = {};
      description = "Audio input/output software volumes to enforce.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.locks != {};
        message = "services.pipewire.audioVolumeLocks.locks must contain at least one lock when enabled.";
      }
      {
        assertion = invalidRawTargets == [];
        message = "services.pipewire.audioVolumeLocks RAW: targets must include a non-empty PipeWire node name.";
      }
      {
        assertion = missingDeviceNames == [];
        message = ''
          services.pipewire.audioVolumeLocks references unknown friendly devices:
          ${lib.concatStringsSep ", " missingDeviceNames}
        '';
      }
    ];
  };
}
