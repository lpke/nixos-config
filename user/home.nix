# ══════════════════════════════════════════════════════════════════
# HOME-MANAGER
# ══════════════════════════════════════════════════════════════════
{ config, pkgs, lib, inputs, osConfig, ... }:

# `flake.nix` outputs > modules > home-manager.users.luke...
let
  systemMonitor = import ./plasma/apps/system-monitor.nix { inherit lib; };
in
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

  home.activation.resetGeneratedSystemMonitorPages =
    lib.hm.dag.entryBefore [ "configure-plasma" ] ''
      run rm -f \
        ${config.xdg.dataHome}/plasma-systemmonitor/monitor.page \
        ${config.xdg.dataHome}/plasma-systemmonitor/inspect.page
    '';

  # Avoid stale compiled KWin scripts after Krohnkite patch changes.
  home.activation.resetKwinQmlCache =
    lib.hm.dag.entryBefore [ "configure-plasma" ] ''
      run rm -rf ${config.xdg.cacheHome}/kwin/qmlcache
    '';

  xdg.configFile = lib.foldl' lib.recursiveUpdate {} [
    # ~/.config/autostart files
    (import ./autostart)
    systemMonitor.customSensorConfigFile
    {
      "mimeapps.list".force = true; # fully overwrite mimeapps when building
      "net.imput.helium/NativeMessagingHosts/com.1password.1password.json".text = builtins.toJSON {
        name = "com.1password.1password";
        description = "1Password BrowserSupport";
        path = "/run/wrappers/bin/1Password-BrowserSupport";
        type = "stdio";
        allowed_origins = [
          "chrome-extension://hjlinigoblmkhjejkmbegnoaljkphmgo/"
          "chrome-extension://bkpbhnjcbehoklfkljkkbbmipaphipgl/"
          "chrome-extension://gejiddohjgogedgjnonbofjigllpkmbf/"
          "chrome-extension://khgocmkkpikpnmmkgmdnfckapcdkgfaf/"
          "chrome-extension://aeblfdkhhhdcdjpifhhbdiojplfjncoa/"
          "chrome-extension://dppgmdbiimibapkepcbdbmkaabgiofem/"
        ];
      } + "\n";
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

  # Override Wine's generated Adobe DNG Converter launcher. Wine points this
  # at a .lnk that currently does not show a usable window from KRunner.
  xdg.dataFile."applications/wine/Programs/Adobe DNG Converter.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Adobe DNG Converter
      GenericName=DNG Converter
      Comment=Launch Adobe DNG Converter under Wine
      Exec=adobe-dng-converter --gui-launcher
      Icon=49AA_Adobe DNG Converter.0
      Terminal=false
      Categories=Graphics;Photography;
      StartupNotify=true
    '';
  };

  # KDE plasma settings (plasma-manager)
  programs.plasma = lib.recursiveUpdate
    (import ./plasma { inherit lib osConfig pkgs; })
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
