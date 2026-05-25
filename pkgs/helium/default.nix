{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  version,
  hash,
}:

let
  pname = "helium";
  appimageArch =
    {
      x86_64-linux = "x86_64";
    }
    .${stdenv.hostPlatform.system}
      or (throw "Helium AppImage packaging is only configured for x86_64-linux");

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-${appimageArch}.AppImage";
    inherit hash;
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };
in
appimageTools.wrapAppImage {
  inherit pname version;
  src = appimageContents;

  extraPkgs = pkgs:
    with pkgs; [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      cairo
      cups
      dbus
      expat
      fontconfig
      freetype
      gdk-pixbuf
      glib
      gtk3
      libdrm
      libgbm
      libnotify
      libpulseaudio
      libsecret
      libxkbcommon
      mesa
      nspr
      nss
      pango
      pipewire
      udev
      wayland
      xdg-utils
      xorg.libX11
      xorg.libXScrnSaver
      xorg.libXcomposite
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXrandr
      xorg.libXrender
      xorg.libXtst
      xorg.libxcb
      xorg.libxshmfence
    ];

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/helium.desktop \
      $out/share/applications/helium.desktop
    install -Dm444 ${appimageContents}/helium.png \
      $out/share/icons/hicolor/256x256/apps/helium.png
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Private Chromium-based web browser";
    homepage = "https://helium.computer/";
    changelog = "https://github.com/imputnet/helium-linux/releases";
    license = with lib.licenses; [
      gpl3Only
      bsd3
    ];
    mainProgram = "helium";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
