{ config, lib, ... }:

let
  cfg = config.programs.browserWebrtcAudioFix;

  disableInputVolumeAdjustmentFlag = "--disable-features=WebRtcAllowInputVolumeAdjustment";
in
{
  options.programs.browserWebrtcAudioFix.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Disable Chromium WebRTC input volume adjustment in wrapped browsers.";
  };

  config = lib.mkIf cfg.enable {
    programs.chromiumBrowserFlags.flags = [ disableInputVolumeAdjustmentFlag ];
  };
}
