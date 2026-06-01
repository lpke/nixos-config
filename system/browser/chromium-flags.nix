{ config, lib, pkgs, ... }:

let
  cfg = config.programs.chromiumBrowserFlags;
  chromiumWrapper = import ./chromium-wrapper.nix { inherit lib; };
  inherit (chromiumWrapper) wrapChromiumBrowser;

  flags = lib.unique cfg.flags;

  browserOverlay = final: prev: {
    vivaldi = wrapChromiumBrowser final {
      name = "vivaldi-chromium-flags";
      package = prev.vivaldi;
      binary = "vivaldi";
      desktopFiles = [ "vivaldi-stable.desktop" ];
      inherit flags;
    };

    google-chrome = wrapChromiumBrowser final {
      name = "google-chrome-chromium-flags";
      package = prev.google-chrome;
      binary = "google-chrome-stable";
      desktopFiles = [ "google-chrome.desktop" ];
      inherit flags;
    };
  };
in
{
  options.programs.chromiumBrowserFlags.flags = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = "Chromium flags applied to configured Chromium-based browsers.";
  };

  config = lib.mkIf (flags != []) {
    nixpkgs.overlays = [ browserOverlay ];
  };
}
