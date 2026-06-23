{
  lib,
  fetchurl,
  appimageTools,
  makeWrapper,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  e2fsprogs,
  expat,
  fontconfig,
  freetype,
  fribidi,
  gdk-pixbuf,
  glib,
  gmp,
  gtk3,
  gtk-layer-shell,
  harfbuzz,
  libgpg-error,
  libayatana-appindicator,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libpulseaudio,
  libsecret,
  libsoup_3,
  libx11,
  libxcb,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxkbcommon,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxshmfence,
  libxtst,
  mesa,
  nspr,
  nss,
  pango,
  pipewire,
  stdenv,
  udev,
  vulkan-loader,
  wayland,
  webkitgtk_4_1,
  xdg-utils,
  zlib,
  version,
  hash,
}:

let
  pname = "voquill";
  src = fetchurl {
    url = "https://github.com/voquill/voquill/releases/download/desktop-v${version}/voquill-desktop_${version}_amd64.AppImage";
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
    e2fsprogs
    expat
    fontconfig
    freetype
    fribidi
    gdk-pixbuf
    glib
    gmp
    gtk3
    gtk-layer-shell
    harfbuzz
    libgpg-error
    libayatana-appindicator
    libdrm
    libgbm
    libglvnd
    libnotify
    libpulseaudio
    libsecret
    libsoup_3
    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxkbcommon
    libxrandr
    libxrender
    libxscrnsaver
    libxshmfence
    libxtst
    mesa
    nspr
    nss
    pango
    pipewire
    stdenv.cc.cc.lib
    udev
    vulkan-loader
    wayland
    webkitgtk_4_1
    xdg-utils
    zlib
  ];
in
stdenv.mkDerivation {
  inherit pname version;

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    makeWrapper ${appimageContents}/AppRun $out/bin/voquill-desktop \
      --prefix NIX_LD_LIBRARY_PATH : /run/opengl-driver/lib:/run/opengl-driver-32/lib:${lib.makeLibraryPath runtimeLibs} \
      --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib:/run/opengl-driver-32/lib:${lib.makeLibraryPath runtimeLibs} \
      --suffix XDG_DATA_DIRS : /run/opengl-driver/share:/run/opengl-driver-32/share:${mesa}/share:${gtk3}/share:${gdk-pixbuf}/share \
      --prefix LIBGL_DRIVERS_PATH : /run/opengl-driver/lib/dri:${mesa}/lib/dri \
      --prefix GBM_BACKENDS_PATH : /run/opengl-driver/lib/gbm:${mesa}/lib/gbm \
      --set-default __EGL_VENDOR_LIBRARY_DIRS /run/opengl-driver/share/glvnd/egl_vendor.d:/run/opengl-driver-32/share/glvnd/egl_vendor.d:${mesa}/share/glvnd/egl_vendor.d

    ln -s $out/bin/voquill-desktop $out/bin/voquill

    install -Dm444 ${appimageContents}/voquill-desktop.desktop \
      $out/share/applications/voquill-desktop.desktop
    substituteInPlace $out/share/applications/voquill-desktop.desktop \
      --replace-fail "Name=voquill-desktop" "Name=Voquill" \
      --replace-fail "Exec=voquill-desktop" "Exec=$out/bin/voquill-desktop"

    install -Dm444 ${appimageContents}/voquill-desktop.png \
      $out/share/icons/hicolor/256x256/apps/voquill-desktop.png

    runHook postInstall
  '';

  meta = {
    description = "AI voice dictation desktop app";
    homepage = "https://github.com/voquill/voquill";
    license = lib.licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "voquill";
  };
}
