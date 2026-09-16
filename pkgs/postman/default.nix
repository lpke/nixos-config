{
  fetchurl,
  lib,
  libdbusmenu,
  postman,
  version,
  hash,
}:

postman.overrideAttrs (oldAttrs: {
  inherit version;

  src = fetchurl {
    name = "postman-${version}.tar.gz";
    url = "https://dl.pstmn.io/download/version/${version}/linux64";
    inherit hash;
  };

  passthru = (oldAttrs.passthru or { }) // {
    updateScript = ./update.sh;
  };

  postFixup =
    # Postman 12 also bundles a shell script named postman. The inherited
    # RPATH loop matches it by name, but patchelf only accepts ELF files.
    lib.replaceStrings
      [ "  patchelf --add-rpath" ]
      [ "  isELF \"$file\" || continue\n  patchelf --add-rpath" ]
      (oldAttrs.postFixup or "")
    + ''
      # Electron loads this dynamically when KDE's global menu registrar exists.
      # Without it, Electron falls back to drawing the menu inside the window.
      patchelf --add-rpath ${lib.makeLibraryPath [ libdbusmenu ]} \
        $out/share/postman/postman
    '';
})
