let
  nixpkgsSource = builtins.fetchTree {
    type = "github";
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "6510408d147d8c5e6d76043e899e9251756f6a75";
    narHash = "sha256-XK4KceonkwD8LuMAt/vNrz982mXJM5jeHAxMwsUXXAQ=";
  };
  pkgs = import nixpkgsSource { system = "x86_64-linux"; };
  adobeSource = builtins.fetchTree {
    type = "github";
    owner = "le-birnes";
    repo = "AdobeWine";
    rev = "9faf503a3dcd8420534f141626667141c49fc7ae";
    narHash = "sha256-hLwI6vB8iG70aj7lFElV6PDu+wJV+7U5jxextrLb/ko=";
  };
  patchDir = adobeSource + "/patches";
  patchNames = builtins.filter (name: pkgs.lib.hasSuffix ".patch" name) (builtins.attrNames (builtins.readDir patchDir));
  sourceBuild = pkgs.wineWow64Packages.unstableFull.overrideAttrs (old: {
    pname = "wine-adobe";
    configureFlags = (old.configureFlags or []) ++ [ "--disable-tests" ];
    patches = (old.patches or []) ++ map (name: builtins.path {
      path = patchDir + "/${name}";
      inherit name;
    }) patchNames;
  });
  runtimeLibs = with pkgs; [
    stdenv.cc.cc.lib freetype fontconfig libunwind libcap cups dbus cairo
    unixodbc samba ncurses libva libpcap libv4l sane-backends libgphoto2 libkrb5
    alsa-lib libpulseaudio libxinerama udev vulkan-loader SDL2 sdl3 libusb1
    gtk3 glib ocl-icd openssl gnutls libGLU libGL libdrm libx11 libxcomposite
    libxcursor libxext libxfixes libxi libxrandr libxrender libxxf86vm
    wayland libxkbcommon libgbm ffmpeg-headless pcsclite
    gst_all_1.gstreamer gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good gst_all_1.gst-plugins-bad gst_all_1.gst-libav
  ];
  runtimePaths = map (lib: "${pkgs.lib.getLib lib}/lib")
    ([ pkgs.stdenv.cc.libc ] ++ runtimeLibs) ++ [ "/run/opengl-driver/lib" ];
in pkgs.stdenv.mkDerivation {
  pname = "adobe-wine";
  version = "11.18-0.2.2";
  src = pkgs.fetchurl {
    url = "https://github.com/le-birnes/AdobeWine/releases/download/v0.2.2/adobewine-0.2.2-x86_64.tar.zst";
    hash = "sha256-Lp024sB9e1/XsBsRQe9emunC/rC2We6o6h2XgqSeO5w=";
  };
  sourceRoot = "opt/adobewine";
  nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.binutils pkgs.zstd ];
  buildInputs = runtimeLibs;
  appendRunpaths = runtimePaths;
  dontConfigure = true;
  dontBuild = true;
  dontAutoPatchelf = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a runtime/. "$out/"
    install -Dm644 LICENSE "$out/share/doc/adobe-wine/LICENSE"
    runHook postInstall
  '';
  postFixup = ''
    autoPatchelf "$out"
    # Keep library paths in the ELF files, not LD_LIBRARY_PATH: Wine launches
    # native browsers, whose older glibc must not inherit this runtime's libc.
    # Remove the optional build-ID note to leave room for both interpreter and
    # RPATH within Wine's limit of 16 ELF program headers.
    for loader in bin/wine lib/wine/x86_64-unix/wine; do
      cp "runtime/$loader" "$out/$loader"
      chmod u+w "$out/$loader"
      objcopy --remove-section .note.gnu.build-id "$out/$loader"
      patchelf --set-interpreter "$(cat "$NIX_CC/nix-support/dynamic-linker")" \
        --set-rpath "${pkgs.lib.concatStringsSep ":" runtimePaths}" "$out/$loader"
      headers=$(readelf -h "$out/$loader" | awk '/Number of program headers:/ { print $NF }')
      test "$headers" -le 16
    done
  '';
  passthru = { inherit sourceBuild adobeSource; };
  meta = {
    description = "AdobeWine 0.2.2, Wine 11.18 with Adobe compatibility patches";
    homepage = "https://github.com/le-birnes/AdobeWine";
    license = pkgs.lib.licenses.lgpl21Plus;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
  };
}
