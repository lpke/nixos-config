# ══════════════════════════════════════════════════════════════════
# NIXOS SYSTEM CONFIGURATION
# ══════════════════════════════════════════════════════════════════
{ config, pkgs, pkgs-unstable, pkgs-neovim, ... }:

let
  gimpLatest = pkgs.callPackage ../pkgs/gimp-latest {};
  adobeDngConverter = pkgs.callPackage ../pkgs/adobe-dng-converter {};
  voquill = pkgs.callPackage ../pkgs/voquill {
    version = "0.0.644";
    hash = "sha256-5vYImGJoI1E1km5LKFgF336QnSUeN2HWkuzjSOOl9D8=";
  };
  bnix = pkgs.callPackage ../pkgs/bnix {
    flakePath = "/etc/nixos";
    baseConfig = "lpnix";
    cudaConfig = "lpnix-llm-cuda";
  };
  piperRestart = pkgs.callPackage ../pkgs/piper-restart {
    commandName = "prs";
  };
  tesseractOcr = pkgs.tesseract.override { enableLanguages = [ "eng" ]; };
  krohnkitePatched = pkgs.kdePackages.krohnkite.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or []) ++ [
      ../patches/krohnkite-unmaximize-before-tiling.patch
      ../patches/krohnkite-stable-timer-parent.patch
      ../patches/krohnkite-ignore-stale-driver.patch
      ../patches/krohnkite-guard-stale-shortcuts.patch
    ];
  });
in
  {
  imports =
    [
      ./hardware-configuration.nix
      ./audio/routing.nix
      ./audio/volume-lock.nix
      ./audio/gains.nix
      ./audio/cli.nix
      ./audio/wireplumber-policy.nix
      ./audio/devices-map.nix
      ./fan-control
      ./browser/chromium-flags.nix
      ./browser/helium.nix
      ./browser/pointer-fix.nix
      ./browser/webrtc-audio.nix
      ./help
      ./local-llm.nix
      ./custom-options.nix
    ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.extraModulePackages = with config.boot.kernelPackages; [ new-lg4ff ];
  boot.kernelModules = [ "hid-logitech-new" ];

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

  systemd.services.nzxt-kraken-z53-lcd = {
    description = "Set NZXT Kraken Z53 LCD to liquid temperature screen";
    wantedBy = [ "multi-user.target" ];
    wants = [ "systemd-udev-settle.service" ];
    after = [
      "systemd-udev-settle.service"
      "nzxt-kraken-z53-fan-control.service"
    ];

    path = [ pkgs.liquidctl ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "5s";
      StartLimitIntervalSec = "3min";
      StartLimitBurst = 12;
    };

    script = ''
      set -euo pipefail

      liquidctl --match "Kraken Z" initialize
      liquidctl --match "Kraken Z" set lcd screen liquid
    '';
  };

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Hide Hibernate from Plasma's launcher/session menus.
  systemd.sleep.settings.Sleep.AllowHibernation = "no";

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "au";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing = {
    enable = true;
    drivers = [ pkgs.hplip ];
  };

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber = {
      enable = true;
    };

    audioBluetoothPolicy = {
      enable = true;
      autoswitchToHeadsetProfile = false; # Keep Bluetooth devices in high-quality output mode unless headset profile is explicitly selected.
    };

    nzxtMicSoftMixer = {
      enable = true;
      wireplumberDeviceName = "nzxt-mic"; # audioDevicesMap.wireplumberDevices key used for this WirePlumber card rule.
    };

    audioDevicesMap = {
      # PipeWire stream endpoints used for routing/locks. Find them with:
      # pw-dump | jq -r '.[] | select(.type=="PipeWire:Interface:Node") | .info.props."node.name" // empty' | sort
      # (or my own `audio list --pipewire`)
      # In custom audio config, use these friendly names, or RAW:<raw-id> to bypass the map.
      pipewireNodes = {
        "DAC" = "alsa_output.usb-JDS_Labs_JDS_Labs_Element_III-00.analog-stereo";
        "airpods" = "bluez_output.2C_32_6A_CB_E0_42.1";
        "Cubilux" = "alsa_output.usb-Generic_USB_Audio-00.analog-stereo";
        "nzxt-mic" = "alsa_input.usb-NZXT_NZXT_USB_MIC_A00017_15_54-00.mono-fallback";
      };
      # Card-level WirePlumber device names used for device rules. Find them with:
      # pw-dump | jq -r '.[] | select(.type=="PipeWire:Interface:Device") | .info.props."device.name" // empty' | sort
      # (or my own `audio list --wireplumber`)
      # In custom audio config, use these friendly names, or RAW:<raw-id> to bypass the map.
      wireplumberDevices = {
        "nzxt-mic" = "alsa_card.usb-NZXT_NZXT_USB_MIC_A00017_15_54-00";
      };
    };

    audioRouting = {
      enable = true;

      combinedOutputs = {
        enable = true;
        outputs = {
          "DAC_Cubilux" = {
            enable = true;
            description = "DAC_Cubilux";
            outputs = [ "DAC" "Cubilux" ];
          };
          "AP_Cubilux" = {
            enable = true;
            description = "AP_Cubilux";
            outputs = [ "airpods" "Cubilux" ];
          };
        };
      };

      loopbacks = {
        enable = true;
        items = {
          "output" = {
            enable = true;
            startByDefault = false;
            description = "default input -> default output";
            input = "DEFAULT_SOURCE";
            output = "DEFAULT_SINK";
          };
          "cubilux" = {
            enable = true;
            startByDefault = true;
            description = "default input -> Cubilux";
            input = "DEFAULT_SOURCE";
            output = "Cubilux";
          };
        };
      };
    };

    audioVolumeLocks = {
      enable = true;
      intervalSeconds = "0.25";
      locks = {
        "nzxt-mic" = {
          enable = true;
          description = "NZXT USB MIC Mono";
          nodeName = "nzxt-mic";
          volume = "1.00";
        };
      };
    };

    audioGains = {
      enable = true;
      gains = {
        "nzxt-mic" = {
          enable = true;
          description = "NZXT USB MIC hardware gain";
          type = "nzxt-usb-mic";
          card = "MIC"; # ALSA card ID from `/proc/asound/cards`, used by `amixer -c <card> ...`
          control = "Mic"; # ALSA mixer knob used by `amixer -c <card> sget/sset <control>`
          extendedRangeGainPercent = 1; # Gain when ALSA exposes the expected 0-233 NZXT range.
          compactRangeGainPercent = 100; # Gain when ALSA exposes the 0-100 NZXT range.
          fallbackGainPercent = 100; # Gain when ALSA exposes an unexpected range.
        };
      };
    };
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
      ll = "ls -l";
      la = "ls -la";
      gs = "git status";
      nn = "pnpm";
      zshrc = "nvim $ZDOTDIR/.zshrc";
      zshrs = "echo 'Reloading using: \`source $ZDOTDIR/.zshrc\` ...' && source $ZDOTDIR/.zshrc && clear";
      r = "ranger --choosedir=$HOME/.config/ranger/lastdir; LASTDIR=`cat $HOME/.config/ranger/lastdir`; cd \"$LASTDIR\"";
      enix = "nvim ~/.config/nixos/configuration.nix";
      bnixnf = "sudo nixos-rebuild switch";
      lnix = "sudo nix-env -p /nix/var/nix/profiles/system --list-generations";
      dnix = "sudo nix-collect-garbage --delete-older-than 14d && nix-collect-garbage --delete-older-than 14d";
      cdnix = "cd ~/.config/nixos";
      "update-helium" = "/home/luke/.config/nixos/pkgs/helium/update.sh";
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

  # for voquill
  systemd.user.services.ydotoold = {
    description = "ydotool Wayland input daemon";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.ydotool}/bin/ydotoold";
      Restart = "on-failure";
    };
  };

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

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "luke" ];
    autoLockMins = 15; # required after changing and building: `systemctl --user restart plasma-powerdevil.service`
  };

  programs.helium = {
    enable = true;
    version = "0.14.7.1";
    hash = "sha256-JPsCvue71hlyS9woHsauX5xM/2PUJ+n8VEjOFquUDno=";
    checkForUpdates = true;
  };

  # Applies to Vivaldi, Google Chrome, Firefox, and Helium.
  # Fixes issue where running Synergy caused browsers to think device is
  # touchscreen due to a virtual device, which in turn caused issues on some
  # websites (eg Notion Calendar).
  programs.browserPointerFix.enable = true;

  # Stops Chromium WebRTC calls from moving the system input volume.
  # Applies to Vivaldi, Google Chrome, and Helium.
  programs.browserWebrtcAudioFix.enable = true;

  # Install firefox
  programs.firefox.enable = true;

  programs.localHelp = {
    enable = true;
    commandName = "help";
  };

  programs.ssh = {
    startAgent = true;
    agentTimeout = "12h";
    askPassword = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
  };

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
      libdrm expat libx11 libxcomposite libxdamage
      libxext libxfixes libxrandr libxcursor
      libxi libxcb libxrender libxkbcommon
      mesa pango cairo alsa-lib
      gtk3 gdk-pixbuf freetype fontconfig
      libgbm libnotify
      # for codex-acp
      libcap
    ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Allow Flatpak and GUI support for Flatpak apps
  services.flatpak.enable = true;
  xdg.portal.enable = true;

  # environment variables in global environment
  # (set early in login process and available to all shells)
  environment = {
    variables = {
      ZDOTDIR = "$HOME/.config/zsh";
      NPM_CONFIG_USERCONFIG = "$HOME/.config/npm/.npmrc";
      PNPM_HOME = "$HOME/.local/share/pnpm";
      BROWSER = "helium";
    };

    sessionVariables = {
      TESSDATA_PREFIX = "${tesseractOcr}/share/tessdata";
      PATH = [
        "$HOME/.local/bin"
        "$HOME/bin"
        "$HOME/.local/share/npm/bin"
        "$HOME/.local/share/pnpm"
      ];
    };

    etc."1password/custom_allowed_browsers" = {
      text = ''
        helium
        vivaldi-bin
      '';
      mode = "0644";
    };
  };

  # System packages
  # see `flake.nix` for how to configure a custom package version
  # eg neovim is using `pkgs-neovim.neovim-unwrapped`
  environment.systemPackages = with pkgs; [
    kdePackages.kate
    kdePackages.krunner
    kdePackages.yakuake
    kdePackages.ksshaskpass # KDE SSH agent passphrase helper
    kdePackages.kfind
    kdePackages.filelight
    kdePackages.accessibility-inspector
    krohnkitePatched # tiling window manager
    kdePackages.kamoso # webcam app
    kdePackages.kdenlive # video editing
    kdePackages.kclock # simple clock/timer app
    tesseractOcr # OCR engine + English language data for Spectacle
    git
    delta # syntax highlighting pager for git
    alacritty
    chezmoi
    oh-my-posh
    tmux
    bnix # guarded NixOS rebuild command
    ranger
    trashy
    wl-clipboard # allow neovim clipboard access (wayland)
    gnumake
    zip
    unzip
    bubblewrap # unprivileged sandboxing tool (used by Codex - codex installed with `npm i -g codex`)
    lm_sensors # sensors, sensors-detect, pwmconfig, fancontrol (you have sensor data but not the CLI tools)
    nvtopPackages.full # terminal GPU/CPU monitor — shows nvidia GPU temp, VRAM, utilisation, fan speed
    hwinfo
    liquidctl # fan control for supported devices
    pciutils # provides commands: lspci, setpci
    usbutils # provides command: lsusb
    lua
    luarocks # lua package manager
    gcc # GNU C/C++ Compiler
    python313
    nodejs_24
    (pnpm.override { nodejs = nodejs_24; }) # pnpm but using specific version
    fnm # "fast node manager" - for ad-hoc node version swapping
    fzf # CLI fuzzy finding
    fd # much faster version of `find`
    ripgrep # much faster version of `grep`
    elinks # text browser/HTML converter used by apidocs.nvim
    file # shows the type of files
    bat # cat clone with syntax highlighting and git integration
    clang # C language
    fastfetch
    piper # mouse assignments
    libratbag
    piperRestart # prs: piper restart
    evtest # input event testing
    vivaldi
    google-chrome
    spotify
    voquill
    flatpak
    gdrive3
    libnotify # required for desktop notifications for some apps (eg my own tool, aspyn)
    jq # json parser
    ydotool # Voquill Wayland paste support
    wtype # Voquill Wayland paste fallback
    # photo/image editing
    gimpLatest
    darktable
    adobeDngConverter
    imagemagick
    ffmpeg-full
    pdfcpu
    # Global/app FPS limiter / HUD (RTSS alternative)
    mangohud # the actual library
    mangojuice # the GUI for the library
    # windows compatibility
    wineWow64Packages.waylandFull
    winetricks
  ];

  programs.neovim = {
    enable = true;
    package = pkgs-neovim.neovim-unwrapped; # "unwrapped" required as `programs.neovim` wraps it
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
