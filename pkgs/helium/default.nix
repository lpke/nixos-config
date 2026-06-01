{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  makeWrapper,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libpulseaudio,
  libsecret,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  pipewire,
  udev,
  wayland,
  xdg-utils,
  xorg,
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
  runtimeLibs = [
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
    libglvnd
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
in
stdenv.mkDerivation {
  inherit pname version;

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    # Avoid appimageTools.wrapAppImage: its bwrap sandbox blocks the setgid
    # 1Password-BrowserSupport wrapper used by native messaging.
    makeWrapper ${appimageContents}/AppRun $out/bin/helium \
      --prefix NIX_LD_LIBRARY_PATH : /run/opengl-driver/lib:/run/opengl-driver-32/lib:${lib.makeLibraryPath runtimeLibs} \
      --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib:/run/opengl-driver-32/lib:${lib.makeLibraryPath runtimeLibs} \
      --suffix XDG_DATA_DIRS : /run/opengl-driver/share:/run/opengl-driver-32/share:${mesa}/share \
      --prefix LIBGL_DRIVERS_PATH : /run/opengl-driver/lib/dri:${mesa}/lib/dri \
      --prefix GBM_BACKENDS_PATH : /run/opengl-driver/lib/gbm:${mesa}/lib/gbm \
      --set-default __EGL_VENDOR_LIBRARY_DIRS /run/opengl-driver/share/glvnd/egl_vendor.d:/run/opengl-driver-32/share/glvnd/egl_vendor.d:${mesa}/share/glvnd/egl_vendor.d

    install -Dm444 ${appimageContents}/helium.desktop \
      $out/share/applications/helium.desktop
    install -Dm444 ${appimageContents}/helium.png \
      $out/share/icons/hicolor/256x256/apps/helium.png

    runHook postInstall
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
