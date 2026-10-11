{ pkgs }:

let
  baseWine = import ./wine.nix;
  fileDialogs = import ./file-dialogs.nix { wine = baseWine; };
  repaint = import ./repaint.nix { wine = baseWine; };
  wine = baseWine.overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      cp ${fileDialogs}/x86_64-windows/comdlg32.dll "$out/lib/wine/x86_64-windows/"
      cp ${fileDialogs}/x86_64-unix/comdlg32.so "$out/lib/wine/x86_64-unix/"
      cp ${repaint}/win32u.so "$out/lib/wine/x86_64-unix/"
    '';
  });
  assets = import ./runtime-assets.nix { inherit pkgs wine; };
  showInstaller = pkgs.pkgsCross.mingwW64.stdenv.mkDerivation {
    pname = "adobe-show-installer";
    version = "1";
    src = ./show-installer.c;
    dontUnpack = true;
    dontConfigure = true;
    buildPhase = ''
      $CC -Wall -Wextra -Werror -O2 -static "$src" -o show-installer.exe -luser32
    '';
    installPhase = ''
      install -Dm755 show-installer.exe "$out/bin/show-installer.exe"
    '';
  };
  prepareSource = builtins.readFile ./prepare-prefix.sh;
  prepare = pkgs.lib.replaceStrings
    [ "@assets@" "@revision@" ]
    [ "${assets}" (builtins.hashString "sha256" prepareSource) ] prepareSource;
  launcher = pkgs.writeShellApplication {
    name = "adobe-photoshop";
    runtimeInputs = [ pkgs.coreutils pkgs.curl pkgs.unzip pkgs.fontconfig pkgs.util-linux pkgs.icoutils wine ];
    text = pkgs.lib.replaceStrings
      [ "@browser@" "@showInstaller@" "@prepare@" "@icons@" ]
      [ "${pkgs.xdg-utils}/bin/xdg-open" "${showInstaller}/bin/show-installer.exe" prepare (builtins.readFile ./install-icons.sh) ]
      (builtins.readFile ./adobe-photoshop.sh);
  };
  cloudLauncher = pkgs.writeShellApplication {
    name = "adobe-creative-cloud";
    text = ''
      case "''${1:-}" in
        -h|--help|help)
          echo 'Usage: adobe-creative-cloud'
          echo 'Open Adobe Creative Cloud to manage your account and installed apps.'
          echo 'Setup and troubleshooting: adobe-photoshop --help'
          exit 0
          ;;
      esac
      exec ${launcher}/bin/adobe-photoshop cloud "$@"
    '';
  };
  photoshopDesktop = pkgs.makeDesktopItem {
    name = "adobe-photoshop";
    desktopName = "Adobe Photoshop";
    genericName = "Image Editor";
    # Plasma can retain desktop entries across Nix profile updates. Resolve the
    # installed command at launch time instead of pinning an obsolete store path.
    exec = "adobe-photoshop run %F";
    icon = "adobe-photoshop";
    categories = [ "Graphics" "Photography" "RasterGraphics" ];
    mimeTypes = [ "image/vnd.adobe.photoshop" "image/x-psd" ];
    startupWMClass = "photoshop.exe";
    startupNotify = true;
  };
  cloudDesktop = pkgs.makeDesktopItem {
    name = "adobe-creative-cloud";
    desktopName = "Adobe Creative Cloud";
    genericName = "Adobe App Manager";
    exec = "adobe-creative-cloud";
    icon = "adobe-creative-cloud";
    categories = [ "Graphics" ];
    startupWMClass = "creative cloud.exe";
    startupNotify = true;
  };
in pkgs.symlinkJoin {
  name = "adobe-photoshop";
  paths = [ launcher cloudLauncher photoshopDesktop cloudDesktop ];
  passthru = { inherit wine showInstaller assets fileDialogs; };
  meta.description = "Isolated Adobe Creative Cloud and Photoshop launcher";
}
