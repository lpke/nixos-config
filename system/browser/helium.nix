{ config, lib, pkgs, ... }:

let
  cfg = config.programs.helium;
  chromiumWrapper = import ./chromium-wrapper.nix { inherit lib; };
  inherit (chromiumWrapper) wrapChromiumBrowser;

  webrtcInputVolumeFeature = "WebRtcAllowInputVolumeAdjustment";
  disableFeaturesPrefix = "--disable-features=";
  removeWebrtcInputVolumeFeature = flag:
    if lib.hasPrefix disableFeaturesPrefix flag then
      let
        features = lib.splitString "," (lib.removePrefix disableFeaturesPrefix flag);
        filteredFeatures = lib.filter (feature: feature != webrtcInputVolumeFeature) features;
      in
      if filteredFeatures == [] then null else "${disableFeaturesPrefix}${lib.concatStringsSep "," filteredFeatures}"
    else
      flag;

  flags = lib.unique config.programs.chromiumBrowserFlags.flags;
  flagsWithInputVolumeAdjustment = lib.filter (flag: flag != null) (map removeWebrtcInputVolumeFeature flags);
  inputVolumeAdjustmentFlagArgs =
    lib.optionalString (flagsWithInputVolumeAdjustment != []) (
      " \\\n" + lib.concatMapStringsSep " \\\n" (flag: "        --add-flags ${lib.escapeShellArg flag}") flagsWithInputVolumeAdjustment
    );

  heliumPackage = pkgs.callPackage ../../pkgs/helium {
    inherit (cfg) version hash;
  };

  helium = wrapChromiumBrowser pkgs {
    name = "helium-chromium-flags";
    package = heliumPackage;
    binary = "helium";
    desktopFiles = [ "helium.desktop" ];
    inherit flags;
  };

  seedMicAutoGainProfile = pkgs.writeShellScript "helium-mic-auto-gain-seed-profile" ''
    set -eu

    configHome="''${XDG_CONFIG_HOME:-$HOME/.config}"
    sourceDir="$configHome/net.imput.helium"
    targetDir="$configHome/helium-mic-auto-gain"
    sourceDefault="$sourceDir/Default"
    targetDefault="$targetDir/Default"

    [ -d "$sourceDefault" ] || exit 0
    mkdir -p "$targetDefault"

    # Do not overwrite profile files while the alternate browser is already open.
    if [ -e "$targetDir/SingletonLock" ] || [ -e "$targetDir/SingletonSocket" ] || [ -e "$targetDir/SingletonCookie" ]; then
      exit 0
    fi

    copy_json() {
      src="$1"
      dst="$2"
      [ -f "$src" ] || return 0
      tmp="$dst.tmp.$$"
      if cp -f "$src" "$tmp" && ${lib.getExe pkgs.jq} empty "$tmp" >/dev/null 2>&1; then
        mv -f "$tmp" "$dst"
      else
        rm -f "$tmp"
      fi
    }

    copy_sqlite() {
      src="$1"
      dst="$2"
      [ -f "$src" ] || return 0
      tmp="$dst.tmp.$$"
      rm -f "$tmp"
      if ${pkgs.sqlite}/bin/sqlite3 "$src" ".timeout 1000" ".backup '$tmp'" >/dev/null 2>&1; then
        mv -f "$tmp" "$dst"
      else
        rm -f "$tmp"
      fi
    }

    copy_json "$sourceDefault/Bookmarks" "$targetDefault/Bookmarks"
    copy_sqlite "$sourceDefault/Shortcuts" "$targetDefault/Shortcuts"
  '';

  heliumMicAutoGain = pkgs.stdenvNoCC.mkDerivation {
    pname = "helium-mic-auto-gain";
    inherit (heliumPackage) version;

    nativeBuildInputs = [ pkgs.makeWrapper ];

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      makeWrapper ${heliumPackage}/bin/helium $out/bin/helium-mic-auto-gain \
        --run '${seedMicAutoGainProfile}; userDataDir="''${XDG_CONFIG_HOME:-$HOME/.config}/helium-mic-auto-gain"; set -- "--user-data-dir=$userDataDir" "$@"'${inputVolumeAdjustmentFlagArgs}

      install -Dm444 ${heliumPackage}/share/applications/helium.desktop \
        $out/share/applications/helium-mic-auto-gain.desktop
      substituteInPlace $out/share/applications/helium-mic-auto-gain.desktop \
        --replace-fail 'Name=Helium' 'Name=Helium (Mic Auto Gain)' \
        --replace-fail 'Exec=helium' 'Exec=helium-mic-auto-gain'

      runHook postInstall
    '';

    meta = heliumPackage.meta // {
      mainProgram = "helium-mic-auto-gain";
    };
  };
in
{
  options.programs.helium = {
    enable = lib.mkEnableOption "Helium Browser";

    version = lib.mkOption {
      type = lib.types.str;
      description = "Helium Browser version to install from GitHub releases.";
    };

    hash = lib.mkOption {
      type = lib.types.str;
      description = "SRI sha256 hash for the pinned Helium AppImage.";
    };

    checkForUpdates = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Check GitHub releases during NixOS activation and print a notice when a newer Helium version exists.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      environment.systemPackages = [
        helium
        heliumMicAutoGain
      ];
    }

    (lib.mkIf cfg.checkForUpdates {
      system.activationScripts.zzzHeliumUpdateNotice.text = ''
        current="${cfg.version}"
        latest="$(
          {
            ${lib.getExe pkgs.curl} -fsSL \
              --connect-timeout 2 \
              --max-time 5 \
              -H 'Accept: application/vnd.github+json' \
              https://api.github.com/repos/imputnet/helium-linux/releases/latest |
              ${lib.getExe pkgs.jq} -r '.tag_name // empty'
          } 2>/dev/null || true
        )"

        if [ -n "$latest" ] && [ "$latest" != "$current" ]; then
          echo "Helium update available: $current -> $latest" >&2
          echo "Update pin: pkgs/helium/update.sh $latest" >&2
        fi
      '';
    })
  ]);
}
