{ config, lib, ... }:

let
  cfg = config.programs.browserPointerFix;

  # Synergy/KDE/Wayland can expose virtual touch input that makes desktop
  # browsers report tablet-like pointer capabilities to web apps.
  desktopPointerBlinkFlags = "--blink-settings=maxTouchPoints=0,primaryHoverType=2,availableHoverTypes=2,primaryPointerType=4,availablePointerTypes=4";

  wrapChromiumDesktopPointerFix = pkgs: { name, package, binary, desktopFiles ? [] }:
    pkgs.symlinkJoin {
      inherit name;
      paths = [ package ];
      nativeBuildInputs = [ pkgs.makeWrapper ];

      postBuild = ''
        wrapProgram "$out/bin/${binary}" \
          --add-flags ${lib.escapeShellArg desktopPointerBlinkFlags}

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

  browserPointerOverlay = final: prev: {
    vivaldi = wrapChromiumDesktopPointerFix final {
      name = "vivaldi-desktop-pointer-fix";
      package = prev.vivaldi;
      binary = "vivaldi";
      desktopFiles = [ "vivaldi-stable.desktop" ];
    };
    google-chrome = wrapChromiumDesktopPointerFix final {
      name = "google-chrome-desktop-pointer-fix";
      package = prev.google-chrome;
      binary = "google-chrome-stable";
      desktopFiles = [ "google-chrome.desktop" ];
    };
  };
in
{
  options.programs.browserPointerFix.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Force desktop pointer media queries in browsers affected by virtual touch input.";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [ browserPointerOverlay ];

    programs.firefox.preferences = lib.mkIf config.programs.firefox.enable {
      "dom.maxtouchpoints.testing.value" = 0;
      "dom.w3c_touch_events.enabled" = 0;
      "ui.allPointerCapabilities" = 6;
      "ui.primaryPointerCapabilities" = 6;
    };

    programs.helium.fixDesktopPointerDetection = true;
  };
}
