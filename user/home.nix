# ══════════════════════════════════════════════════════════════════
# HOME-MANAGER
# ══════════════════════════════════════════════════════════════════
{ config, pkgs, lib, inputs, ... }:

# `flake.nix` outputs > modules > home-manager.users.luke...
{
  imports = [
    inputs.xremap-flake.homeManagerModules.default
  ];

  home.stateVersion = "25.11";
  home.username = "luke";
  home.homeDirectory = "/home/luke";
  home.packages = [
    # enables running `xremap` as a command
    inputs.xremap-flake.packages.${pkgs.stdenv.hostPlatform.system}.default
    # enables running `rc2nix` as a command
    inputs.plasma-manager.packages.${pkgs.stdenv.hostPlatform.system}.rc2nix
  ];
  programs.home-manager.enable = true;

  xdg.configFile = lib.foldl' lib.recursiveUpdate {} [
    # ~/.config/autostart files
    (import ./autostart)
    {
      "mimeapps.list".force = true; # fully overwrite mimeapps when building
    }
  ];

  # Default apps: ~/.config/mimeapps.list
  xdg.mimeApps = lib.recursiveUpdate
    (import ./mimeapps)
    {
      enable = true;
    };

  # Custom .desktop files for: ~/.local/share/applications
  xdg.desktopEntries = import ./desktopEntries;

  # KDE plasma settings (plasma-manager)
  programs.plasma = lib.recursiveUpdate
    (import ./plasma { inherit lib; })
    {
      enable = true;
    };

  # keyboard and mouse remaps
  services.xremap = lib.recursiveUpdate
    (import ./xremap)
    {
      enable = true;
      withKDE = true;
      debug = false; # journalctl --user -u xremap.service -f
    }; 
}
