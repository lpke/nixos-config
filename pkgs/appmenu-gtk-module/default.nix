{
  lib,
  stdenv,
  fetchurl,
  meson,
  ninja,
  pkg-config,
  glib,
  gtk3,
  libX11,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "appmenu-gtk-module";
  version = "25.04";

  src = fetchurl {
    url = "https://deb.debian.org/debian/pool/main/a/appmenu-gtk-module/appmenu-gtk-module_${finalAttrs.version}.orig.tar.xz";
    hash = "sha256-KrjMVsShTLng3SQ1E5LDyNllplxOAsFVwaLoy6WyG4Y=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    glib
  ];

  buildInputs = [
    glib
    gtk3
    libX11
  ];

  mesonFlags = [
    "-Dgtk=3"
    "-Dtests=false"
    "-Dgtk_doc=false"
  ];

  postPatch = ''
    substituteInPlace src/gtk-3.0/meson.build \
      --replace-fail \
        "install_dir: join_paths(gtk3.get_variable(pkgconfig:'libdir'),'gtk-3.0','modules')" \
        "install_dir: join_paths(get_option('libdir'), 'gtk-3.0', 'modules')"
  '';

  postFixup = ''
    glib-compile-schemas "$out/share/gsettings-schemas/${finalAttrs.pname}-${finalAttrs.version}/glib-2.0/schemas"
  '';

  meta = {
    description = "GTK module for exporting application menus to desktop global menu bars";
    homepage = "https://gitlab.com/vala-panel-project/vala-panel-appmenu";
    license = lib.licenses.lgpl3Plus;
    platforms = lib.platforms.linux;
  };
})
