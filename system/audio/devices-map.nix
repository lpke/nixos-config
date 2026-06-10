{ lib, ... }:

{
  options.services.pipewire.audioDevicesMap = lib.mkOption {
    type = lib.types.submodule {
      options = {
        pipewireNodes = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          example = {
            "DAC" = "alsa_output.usb-JDS_Labs_JDS_Labs_Element_III-00.analog-stereo";
            "nzxt-mic" = "alsa_input.usb-NZXT_NZXT_USB_MIC_A00017_15_54-00.mono-fallback";
          };
          description = "Friendly names for PipeWire node.name values used by routing and software volume locks.";
        };

        wireplumberDevices = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          example = {
            "nzxt-mic" = "alsa_card.usb-NZXT_NZXT_USB_MIC_A00017_15_54-00";
          };
          description = "Friendly names for WirePlumber device.name values used by card-level WirePlumber rules.";
        };
      };
    };
    default = {
      pipewireNodes = {};
      wireplumberDevices = {};
    };
    example = {
      pipewireNodes = {
        "DAC" = "alsa_output.usb-JDS_Labs_JDS_Labs_Element_III-00.analog-stereo";
        "nzxt-mic" = "alsa_input.usb-NZXT_NZXT_USB_MIC_A00017_15_54-00.mono-fallback";
      };
      wireplumberDevices = {
        "nzxt-mic" = "alsa_card.usb-NZXT_NZXT_USB_MIC_A00017_15_54-00";
      };
    };
    description = "Friendly audio IDs grouped by the audio layer that consumes them.";
  };
}
