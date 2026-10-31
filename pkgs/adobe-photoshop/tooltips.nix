{ wine }:

wine.sourceBuild.overrideAttrs (old: {
  pname = "adobe-tooltips";
  patches = old.patches ++ [ ./tracking-tooltip-delete.patch ];
  # Photoshop uses tracking tooltips for document tabs. Build both common
  # controls versions so applications with and without a v6 manifest agree.
  buildPhase = ''
    runHook preBuild
    make -j2 dlls/comctl32/all dlls/comctl32_v6/all
    runHook postBuild
  '';
  installPhase = ''
    install -Dm644 dlls/comctl32/x86_64-windows/comctl32.dll "$out/comctl32.dll"
    install -Dm644 dlls/comctl32_v6/x86_64-windows/comctl32_v6.dll "$out/comctl32_v6.dll"
  '';
  postInstall = "";
  postFixup = "";
})
