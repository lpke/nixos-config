# ══════════════════════════════════════════════════════════════════
# NIXOS SYSTEM CONFIGURATION
# ══════════════════════════════════════════════════════════════════
{ config, pkgs, pkgs-unstable, pkgs-neovim, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.kernelParams = [
    "kvm.enable_virt_at_load=0" # disable KVM at boot to workaround a virtualbox issue
    "nvidia-drm.fbdev=1" # use nvidia for framebuffers (TTY)
  ];

  networking = {
    hostName = "lpnix";
    networkmanager.enable = true;

    # Enable newer wireless management with `iwd`
    # (replaces `wpa_supplicant`)
    networkmanager.wifi.backend = "iwd";
    wireless.iwd = {
      enable = true;
      settings = {
        Network = {
          EnableIPv6 = true;
        };
        Settings = {
          AutoConnect = true;
        };
      };
    };

    # needed for `synergy` to work
    firewall.enable = false;
  };

  # ensure wifi loads correctly (reload if it doesnt)
  systemd.services.wifi-fix = {
    description = "WIFI-FIX: Reload wireless driver if WiFi interface is missing";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    before = [ "iwd.service" "NetworkManager.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "journal+console";
      StandardError = "journal+console";
      ExecStart = pkgs.writeShellScript "wifi-fix" ''
      # Find wireless PCI device (class 0x028000) and its driver
      WIFI_DRIVER=""
      for dev in /sys/bus/pci/devices/*; do
      if [ -f "$dev/class" ]; then
      class=$(${pkgs.coreutils}/bin/cat "$dev/class")
      # PCI class 0x028000 = Network controller (wireless)
      if [ "$class" = "0x028000" ]; then
      if [ -L "$dev/driver" ]; then
      WIFI_DRIVER=$(${pkgs.coreutils}/bin/basename $(${pkgs.coreutils}/bin/readlink "$dev/driver"))
      fi
      break
      fi
      fi
      done

      if [ -z "$WIFI_DRIVER" ]; then
      echo "No wireless PCI device or driver found."
      exit 0
      fi

      # Wait for interface to appear (up to 3 seconds)
      for i in 1 2 3; do
      for iface in /sys/class/net/*; do
      if [ -d "$iface/wireless" ]; then
      echo "Wireless interface found, no action needed."
      exit 0
      fi
      done
      ${pkgs.coreutils}/bin/sleep 1
      done

      # Reload the detected driver
      echo "No wireless interface found, reloading $WIFI_DRIVER..."
      ${pkgs.kmod}/bin/modprobe -r "$WIFI_DRIVER"
      ${pkgs.coreutils}/bin/sleep 1
      ${pkgs.kmod}/bin/modprobe "$WIFI_DRIVER"
      '';
    };
  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        # Shows battery charge of connected devices on supported
        # Bluetooth adapters. Defaults to 'false'.
        Experimental = true;
        # When enabled other devices can connect faster to us, however
        # the tradeoff is increased power consumption. Defaults to
        # 'false'.
        FastConnectable = true;
      };
      Policy = {
        # Enable all controllers when they are found. This includes
        # adapters present on start as well as adapters that are plugged
        # in later on. Defaults to 'true'.
        AutoEnable = true;
      };
    };
  };

  # Set your time zone.
  time.timeZone = "Australia/Sydney";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_AU.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_AU.UTF-8";
    LC_IDENTIFICATION = "en_AU.UTF-8";
    LC_MEASUREMENT = "en_AU.UTF-8";
    LC_MONETARY = "en_AU.UTF-8";
    LC_NAME = "en_AU.UTF-8";
    LC_NUMERIC = "en_AU.UTF-8";
    LC_PAPER = "en_AU.UTF-8";
    LC_TELEPHONE = "en_AU.UTF-8";
    LC_TIME = "en_AU.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Nvidia
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    open = false;
  };
  hardware.graphics.enable = true;

  # ZSA Moonlander Keyboard - Enable flashing
  hardware.keyboard.zsa.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "au";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Use zsh instead of bash
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    histSize = 1000000;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      cls = "clear";
      ll = "ls -l";
      la = "ls -la";
      gs = "git status";
      nn = "pnpm";
      zshrc = "nvim $ZDOTDIR/.zshrc";
      zshrs = "echo 'Reloading using: \`source $ZDOTDIR/.zshrc\` ...' && source $ZDOTDIR/.zshrc && clear";
      r = "ranger --choosedir=$HOME/.config/ranger/lastdir; LASTDIR=`cat $HOME/.config/ranger/lastdir`; cd \"$LASTDIR\"";
      enix = "nvim ~/.config/nixos/configuration.nix";
      bnix = "sudo nixos-rebuild switch --flake /etc/nixos#lpnix";
      bnixnf = "sudo nixos-rebuild switch";
      lnix = "sudo nix-env -p /nix/var/nix/profiles/system --list-generations";
      dnix = "sudo nix-collect-garbage --delete-older-than 14d && nix-collect-garbage --delete-older-than 14d";
      cdnix = "cd ~/.config/nixos";
      xrs = "systemctl --user restart xremap"; # "xremap restart"
      wrs = "sudo modprobe -r iwlwifi 2>/dev/null; sudo modprobe iwlwifi"; # "wifi restart" (unloads/loads iwlwifi kernel module, fixes no wifi issue)
    };
  };

  # auto-load per-project dev shells from .envrc + flake.nix
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    silent = false;
  };

  # useful explanations: https://dev.to/patimapoochai/how-to-edit-the-sudoers-file-in-nixos-with-examples-4k34
  security.sudo = {
    enable = true;
    execWheelOnly = false;
    wheelNeedsPassword = false;

    # Preserve Wayland environment with sudo (fix clipboard in sudo nvim)
    extraConfig = ''
      Defaults env_keep += "WAYLAND_DISPLAY XDG_RUNTIME_DIR"
    '';
  };

  # add myself to `uinput` to get xremap working
  hardware.uinput.enable = true;
  users.groups.uinput.members = [ "luke" ];

  users.defaultUserShell = pkgs.zsh;
  users.users.luke = {
    isNormalUser = true;
    description = "luke";
    extraGroups = [ "networkmanager" "wheel" "input" "uinput" "vboxusers" ];
    useDefaultShell = true;
    packages = with pkgs; [
      discord
      # runescape
      bolt-launcher
      runelite
      # minecraft
      (prismlauncher.override {
        additionalPrograms = [];
        jdks = [
          pkgs.jdk21
          pkgs.jdk17
          pkgs.jdk8
        ];
      })
    ];
  };

  # Install firefox
  programs.firefox.enable = true;

  # Install steam
  programs.steam = {
    enable = true;
  };

  # run non-nix-patched executables
  programs.nix-ld = {
    enable = true;
    # covers common browser + native-module needs (safety net)
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib openssl curl
      glib nss nspr atk at-spi2-atk at-spi2-core cups dbus
      libdrm expat xorg.libX11 xorg.libXcomposite xorg.libXdamage
      xorg.libXext xorg.libXfixes xorg.libXrandr xorg.libXcursor
      xorg.libXi xorg.libxcb xorg.libXrender libxkbcommon
      mesa pango cairo alsa-lib
      gtk3 gdk-pixbuf freetype fontconfig
      libgbm libnotify
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Allow Flatpak and GUI support for Flatpak apps
  services.flatpak.enable = true;
  xdg.portal.enable = true;

  # environment variables in global environment
  # (set early in login process and available to all shells)
  environment.sessionVariables = {
    PATH = [ "$HOME/.local/bin" ];
  };

  # System packages
  # see `flake.nix` for how to configure a custom package version
  # eg neovim is using `pkgs-neovim.neovim`
  environment.systemPackages = with pkgs; [
    kdePackages.kate
    kdePackages.krunner
    kdePackages.yakuake
    kdePackages.kfind
    kdePackages.filelight
    kdePackages.accessibility-inspector
    kdePackages.krohnkite # tiling window manager
    kdePackages.kamoso # webcam app
    kdePackages.kdenlive # video editing
    git
    delta # syntax highlighting pager for git
    alacritty
    chezmoi
    oh-my-posh
    tmux
    pkgs-neovim.neovim
    ranger
    trashy
    wl-clipboard # allow neovim clipboard access (wayland)
    gnumake
    zip
    unzip
    hwinfo
    pciutils # provides commands: lspci, setpci
    python313
    nodejs_24
    nodePackages.pnpm
    fzf # CLI fuzzy finding
    fd # much faster version of `find`
    ripgrep # much faster version of `grep`
    clang # C language
    neofetch
    piper # mouse assignments
    libratbag
    evtest # input event testing
    vivaldi
    _1password-gui
    spotify
    flatpak
    gdrive3
    normcap # OCR image to text based on screen selection
    libnotify # required for desktop notifications for some apps (eg my own tool, aspyn)
    jq # json parser
    # Global/app FPS limiter / HUD (RTSS alternative)
    mangohud # the actual library
    mangojuice # the GUI for the library
    # windows compatibility
    winePackages.waylandFull
    wineWowPackages.waylandFull
    winetricks
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  # Fonts
  fonts.enableDefaultPackages = true;
  fonts.fontconfig.useEmbeddedBitmaps = true;
  fonts.packages = with pkgs; [
    jetbrains-mono
    nerd-fonts.jetbrains-mono
    inter
  ];

  # Virtualisation
  virtualisation.virtualbox.host.enable = true; # enable VirtualBox - do NOT add to system packages
  users.extraGroups.vboxusers.members = [ "user-with-access-to-virtualbox" ]; # users require `vboxusers` group to use VirtualBox

  system.stateVersion = "25.11";
}
