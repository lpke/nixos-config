{ wine }:

wine.sourceBuild.overrideAttrs (old: {
  pname = "adobe-file-dialogs";
  patches = old.patches ++ [ ./portal-file-type.patch ./portal-custom-dialogs.patch ];
  # Build only the matching dialog module and its build tools/import libraries.
  buildPhase = ''
    runHook preBuild
    make -j2 dlls/comdlg32/all
    runHook postBuild
  '';
  installPhase = ''
    mkdir -p "$out/x86_64-windows" "$out/x86_64-unix"
    cp dlls/comdlg32/x86_64-windows/comdlg32.dll "$out/x86_64-windows/"
    cp dlls/comdlg32/comdlg32.so "$out/x86_64-unix/"
  '';
  postInstall = "";
  postFixup = "";
})
