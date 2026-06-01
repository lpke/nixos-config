{ config, lib, pkgs, ... }:

let
  cfg = config.programs.browserWebrtcAudioFix;

  disableInputVolumeAdjustmentFlag = "--disable-features=WebRtcAllowInputVolumeAdjustment";

  wrapChromiumWebrtcAudioFix = pkgs: { name, package, binary, desktopFiles ? [] }:
    pkgs.symlinkJoin {
      inherit name;
      paths = [ package ];
      nativeBuildInputs = [ pkgs.makeWrapper ];

      postBuild = ''
        wrapProgram "$out/bin/${binary}" \
          --add-flags ${lib.escapeShellArg disableInputVolumeAdjustmentFlag}

        for desktopFile in ${lib.escapeShellArgs desktopFiles}; do
          desktopPath="$out/share/applications/$desktopFile"
          if [ -e "$desktopPath" ]; then
            cp --remove-destination "$(readlink -f "$desktopPath")" "$desktopPath"
            chmod u+w "$desktopPath"
            substituteInPlace "$desktopPath" \
              --replace-fail "${package}/bin/${binary}" "$out/bin/${binary}"
          fi
        done
      '';

      meta = package.meta or {};
    };

  browserWebrtcAudioOverlay = final: prev: {
    vivaldi = wrapChromiumWebrtcAudioFix final {
      name = "vivaldi-webrtc-audio-fix";
      package = prev.vivaldi;
      binary = "vivaldi";
      desktopFiles = [ "vivaldi-stable.desktop" ];
    };
    google-chrome = wrapChromiumWebrtcAudioFix final {
      name = "google-chrome-webrtc-audio-fix";
      package = prev.google-chrome;
      binary = "google-chrome-stable";
      desktopFiles = [ "google-chrome.desktop" ];
    };
  };
in
{
  options.programs.browserWebrtcAudioFix.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Disable Chromium WebRTC input volume adjustment in wrapped browsers.";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [ browserWebrtcAudioOverlay ];

    programs.helium.disableWebrtcInputVolumeAdjustment = lib.mkDefault true;
  };
}
