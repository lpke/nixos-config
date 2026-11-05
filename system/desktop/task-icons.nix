{ ... }:
{
  nixpkgs.overlays = [
    (_final: previous: {
      kdePackages = previous.kdePackages.overrideScope (_kdeFinal: kdePrevious: {
        plasma-desktop = (import ../../pkgs/plasma-task-icons { pkgs = previous; }) kdePrevious.plasma-desktop;
      });
    })
  ];
}
