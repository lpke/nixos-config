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

  # Electron loads this dynamically when KDE's global menu registrar exists.
  # Without it, Electron falls back to drawing the menu inside the window.
  postFixup = (oldAttrs.postFixup or "") + ''
    patchelf --add-rpath ${lib.makeLibraryPath [ libdbusmenu ]} \
      $out/share/postman/postman
  '';
})
