{
  # GENERATE FROM ~/.config: `rc2nix`
  #   filter: `rc2nix | grep -i '<search>'
  #   copy to clipboard: `rc2nix | wl-copy`

  # ALL OPTIONS: https://nix-community.github.io/plasma-manager/options.xhtml
  #   Covers many that `rc2nix` does not capture

  # APPLYING CHANGES: To update after editing this file, rebuild nixos then log out/back in
  #   All keymaps are still editable through KDE's GUI
  #   KDE's GUI will always show the default keymap
  #   plasma-manager will NOT override a keymap unless it's defined in this file

  # NOT ALL SETTINGS ARE HERE - only ones I want to disable/change/explicitly keep

  shortcuts = import ./shortcuts.nix;

  panels = import ./panels.nix;

  configFile = import ./configFile.nix;

  dataFile = import ./dataFile.nix;

  kwin = {
    effects.desktopSwitching.animation = "off"; # default: "slide"
  };
}
