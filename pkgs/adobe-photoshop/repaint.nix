{ wine }:

wine.sourceBuild.overrideAttrs (old: {
  pname = "adobe-repaint";
  patches = old.patches ++ [
    ./resize-repaint.patch
    ./offscreen-pacing.patch
    ./present-completion.patch
    ./scrollbar-skin.patch
  ];
  buildPhase = ''
    make -j2 dlls/win32u/win32u.so
  '';
  installPhase = ''
    install -Dm755 dlls/win32u/win32u.so "$out/win32u.so"
  '';
  postInstall = "";
  postFixup = "";
})
