{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  pkg-config,
  clang,
  mold,
  fontconfig,
  freetype,
  libxkbcommon,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
  wayland,
  vulkan-loader,
  gst_all_1,
  kdePackages,
  curl,
  ffmpeg,
  libnotify,
  xdg-utils,
}:

rustPlatform.buildRustPackage rec {
  pname = "kglance";
  version = "0.3.0-unstable-2026-08-29";

  src = fetchFromGitHub {
    owner = "Mintori09";
    repo = "kglance";
    rev = "6f5a9dda7b144520d171bbcbf3accb175df866b6";
    hash = "sha256-HS5ipJXtBprFf8lZumYETdeT/hLsevr2pS2ohP3+uHY=";
  };

  cargoHash = "sha256-CXpJbWp7PekMW7czN/sqFQfKc4Vwz6SNot4avIKFrlw=";

  # kstring 2.0.4 requires Rust 1.96, one release newer than NixOS 26.05.
  cargoPatches = [ ./kstring-rust-1.95.patch ];

  nativeBuildInputs = [
    clang
    makeWrapper
    mold
    pkg-config
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    fontconfig
    freetype
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    libx11
    libxcursor
    libxi
    libxkbcommon
    libxrandr
    vulkan-loader
    wayland
  ];

  # Two upstream tests require a host icon theme and the optional Typst CLI.
  # The remaining test suite compiles the whole application a second time.
  doCheck = false;

  postInstall = ''
    install -Dm444 data/kglance.desktop \
      "$out/share/applications/kglance.desktop"
    install -Dm444 data/kglance.svg \
      "$out/share/icons/hicolor/scalable/apps/kglance.svg"
    install -Dm444 data/kglance-rust.desktop \
      "$out/share/kio/servicemenus/kglance-rust.desktop"

    wrapProgram "$out/bin/kglance" \
      --prefix PATH : ${lib.makeBinPath [
        curl
        ffmpeg
        fontconfig
        kdePackages.kconfig
        libnotify
        xdg-utils
      ]} \
      --prefix LD_LIBRARY_PATH : /run/opengl-driver/lib:${lib.makeLibraryPath [
        libx11
        libxcursor
        libxi
        libxkbcommon
        libxrandr
        vulkan-loader
        wayland
      ]} \
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" [
        gst_all_1.gst-plugins-base
        gst_all_1.gst-plugins-good
        gst_all_1.gst-plugins-bad
        gst_all_1.gst-plugins-ugly
        gst_all_1.gst-libav
      ]}
  '';

  meta = {
    description = "Quick file previewer for KDE Plasma 6";
    homepage = "https://github.com/Mintori09/kglance";
    license = lib.licenses.agpl3Only;
    mainProgram = "kglance";
    platforms = lib.platforms.linux;
  };
}
