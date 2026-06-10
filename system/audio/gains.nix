{ config, lib, ... }:

let
  cfg = config.services.pipewire.audioGains;

  gainPercentOk = value: value >= 0 && value <= 100;
  gainConfigOk = gain:
    gainPercentOk gain.defaultGainPercent
    && gainPercentOk gain.extendedRangeGainPercent
    && gainPercentOk gain.compactRangeGainPercent
    && gainPercentOk gain.fallbackGainPercent;

  invalidGainPercents = lib.filterAttrs (_: gain: !(gainConfigOk gain)) cfg.gains;
  invalidNzxtRanges = lib.filterAttrs
    (_: gain: gain.type == "nzxt-usb-mic" && builtins.elem gain.compactRangeMax gain.extendedRangeMaxes)
    cfg.gains;
in
{
  options.services.pipewire.audioGains = {
    enable = lib.mkEnableOption "ALSA hardware gain management";

    intervalSeconds = lib.mkOption {
      type = lib.types.str;
      default = "0.25";
      description = "Delay after audio change events before reapplying gain targets.";
    };

    service = lib.mkOption {
      type = lib.types.str;
      default = "audio-gains.service";
      description = "User systemd service name for the audio gain watcher.";
    };

    gains = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable this hardware gain target.";
          };

          description = lib.mkOption {
            type = lib.types.str;
            default = name;
            description = "Human-readable gain target label.";
          };

          type = lib.mkOption {
            type = lib.types.enum [ "alsa" "nzxt-usb-mic" ];
            default = "alsa";
            description = "Gain target implementation.";
          };

          card = lib.mkOption {
            type = lib.types.str;
            description = "ALSA card ID passed to amixer -c.";
          };

          control = lib.mkOption {
            type = lib.types.str;
            description = "ALSA capture control for this gain target.";
          };

          defaultGainPercent = lib.mkOption {
            type = lib.types.either lib.types.int lib.types.float;
            default = 100;
            description = "Default hardware gain percent for generic ALSA gain targets.";
          };

          extendedRangeMaxes = lib.mkOption {
            type = lib.types.listOf lib.types.int;
            default = [ 233 255 ];
            description = "NZXT ALSA max values treated as the extended-range state.";
          };

          compactRangeMax = lib.mkOption {
            type = lib.types.int;
            default = 100;
            description = "NZXT ALSA max value treated as the compact-range state.";
          };

          extendedRangeGainPercent = lib.mkOption {
            type = lib.types.either lib.types.int lib.types.float;
            default = 1;
            description = "NZXT gain percent for the extended-range state.";
          };

          compactRangeGainPercent = lib.mkOption {
            type = lib.types.either lib.types.int lib.types.float;
            default = 100;
            description = "NZXT gain percent for the compact-range state.";
          };

          fallbackGainPercent = lib.mkOption {
            type = lib.types.either lib.types.int lib.types.float;
            default = 100;
            description = "NZXT gain percent for unexpected mixer ranges.";
          };
        };
      }));
      default = {};
      description = "ALSA hardware gain targets.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.gains != {};
        message = "services.pipewire.audioGains.gains must contain at least one gain target when enabled.";
      }
      {
        assertion = invalidGainPercents == {};
        message = "services.pipewire.audioGains gain percentages must be between 0 and 100.";
      }
      {
        assertion = invalidNzxtRanges == {};
        message = "services.pipewire.audioGains NZXT compactRangeMax must not also appear in extendedRangeMaxes.";
      }
    ];
  };
}
