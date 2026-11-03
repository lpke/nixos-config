{ config, pkgs, ... }:
{
  # Keep pointer restoration outside GPU-fenced surface commits. Existing pointer
  # lock/confinement handling stays upstream; no application-specific conditions.
  nixpkgs.overlays = [
    (_final: previous: {
      kdePackages = previous.kdePackages.overrideScope (_kdeFinal: kdePrevious: {
        kwin = (import ../../pkgs/wayland-pointer-warp/kwin.nix { pkgs = previous; }) kdePrevious.kwin;
      });
    })
  ];

  # Preserve the configured X11 font directory without rebuilding KWin against
  # this runtime-only Xwayland change.
  programs.xwayland.package =
    (import ../../pkgs/wayland-pointer-warp/xwayland.nix { inherit pkgs; })
      (pkgs.xwayland.override { defaultFontPath = config.programs.xwayland.defaultFontPath; });
}
