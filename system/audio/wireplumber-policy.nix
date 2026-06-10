{ config, lib, ... }:

let
  bluetooth = config.services.pipewire.audioBluetoothPolicy;
  nzxt = config.services.pipewire.nzxtMicSoftMixer;
  devicesMap = config.services.pipewire.audioDevicesMap;

  rawPrefix = "RAW:";
  isRaw = value: lib.hasPrefix rawPrefix value;
  rawName = value: lib.removePrefix rawPrefix value;
  resolvedWirePlumberDeviceName =
    if isRaw nzxt.wireplumberDeviceName
    then rawName nzxt.wireplumberDeviceName
    else devicesMap.wireplumberDevices.${nzxt.wireplumberDeviceName};
in
{
  options.services.pipewire.audioBluetoothPolicy = {
    enable = lib.mkEnableOption "custom Bluetooth audio WirePlumber policy";

    autoswitchToHeadsetProfile = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Allow WirePlumber to switch Bluetooth devices to headset profile when apps request microphone/call audio.";
    };
  };

  options.services.pipewire.nzxtMicSoftMixer = {
    enable = lib.mkEnableOption "NZXT USB MIC software mixer WirePlumber rule";

    wireplumberDeviceName = lib.mkOption {
      type = lib.types.str;
      default = "nzxt-mic";
      description = "Friendly audioDevicesMap.wireplumberDevices name, or RAW:<wireplumber-device-name> for a raw WirePlumber device.name.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (nzxt.enable && !(isRaw nzxt.wireplumberDeviceName)) {
      assertions = [
        {
          assertion = builtins.hasAttr nzxt.wireplumberDeviceName devicesMap.wireplumberDevices;
          message = "services.pipewire.nzxtMicSoftMixer.wireplumberDeviceName references an unknown audioDevicesMap.wireplumberDevices key.";
        }
      ];
    })

    (lib.mkIf bluetooth.enable {
      services.pipewire.wireplumber.extraConfig."10-bluez-bluetooth-policy" = {
        "wireplumber.settings" = {
          "bluetooth.autoswitch-to-headset-profile" = bluetooth.autoswitchToHeadsetProfile;
        };
      };
    })

    (lib.mkIf nzxt.enable {
      services.pipewire.wireplumber.extraConfig."51-nzxt-usb-mic-soft-mixer" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              {
                "device.name" = resolvedWirePlumberDeviceName;
              }
            ];
            actions.update-props = {
              "api.alsa.soft-mixer" = true;
            };
          }
        ];
      };
    })
  ];
}
