# ══════════════════════════════════════════════════════════════════
# HOME-MANAGER
# ══════════════════════════════════════════════════════════════════
{ config, pkgs, lib, inputs, osConfig, ... }:

# `flake.nix` outputs > modules > home-manager.users.luke...
let
  systemMonitor = import ./plasma/apps/system-monitor.nix { inherit lib; };
  windowTitleApplet = pkgs.callPackage ../pkgs/window-title-applet {};
  synergyTrayIconPadder = pkgs.writeShellApplication {
    name = "synergy-tray-icon-padder";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.imagemagick
      pkgs.inotify-tools
    ];
    text = ''
      tray_dir="$XDG_RUNTIME_DIR/tray-icon"
      icon_path="$tray_dir/tray-icon-2-0.png"

      pad_icon() {
        local content_bounds
        local padded_icon="$tray_dir/.tray-icon-2-0.padded.png"

        [ -f "$icon_path" ] || return 0
        content_bounds=$(magick identify -format '%@' "$icon_path")
        [ "$content_bounds" != "24x24+4+4" ] || return 0

        magick "$icon_path" \
          -resize 24x24 \
          -gravity center \
          -background none \
          -extent 32x32 \
          "$padded_icon"
        mv -- "$padded_icon" "$icon_path"
      }

      mkdir -p -- "$tray_dir"
      pad_icon

      inotifywait --monitor --quiet --event close_write --format '%f' "$tray_dir" |
        while IFS= read -r changed_file; do
          if [ "$changed_file" = "tray-icon-2-0.png" ]; then
            pad_icon
          fi
        done
    '';
  };
in
{
  imports = [
    inputs.xremap-flake.homeManagerModules.default
    ./kglance.nix
    ./xremap/mode-controller.nix
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

  # Replace the KDE Store copy with the patched Home Manager-managed applet.
  home.activation.removeUnmanagedWindowTitleApplet =
    lib.hm.dag.entryBefore [ "linkGeneration" ] ''
      target="${config.xdg.dataHome}/plasma/plasmoids/org.kde.windowtitle"
      if [ -d "$target" ] && [ ! -L "$target" ]; then
        run rm -rf "$target"
      fi
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

  # Plasma 6.6 removed the private appmenu QML module imported by upstream 0.9.0.
  xdg.dataFile."plasma/plasmoids/org.kde.windowtitle" = {
    force = true;
    source = "${windowTitleApplet}/share/plasma/plasmoids/org.kde.windowtitle";
  };

  # Synergy's Flatpak tray process uses AppIndicator. It must reach KDE's
  # StatusNotifier watcher and place its generated icon where Plasma can read it.
  xdg.dataFile."flatpak/overrides/com.symless.synergy" = {
    force = true;
    text = ''
      [Context]
      filesystems=xdg-run/tray-icon:create;

      [Session Bus Policy]
      org.kde.StatusNotifierWatcher=talk
    '';
  };

  systemd.user.services.synergy-tray-icon-padder = {
    Unit = {
      Description = "Add padding to Synergy's tray icon";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${synergyTrayIconPadder}/bin/synergy-tray-icon-padder";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

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
