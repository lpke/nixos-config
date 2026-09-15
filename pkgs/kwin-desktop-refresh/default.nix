{ lib, stdenv, cmake, pkg-config, kdePackages, libdrm, libepoxy, wayland }:

stdenv.mkDerivation {
  pname = "kwin-desktop-refresh";
  version = "1.0.1";
  src = ./.;

  nativeBuildInputs = [ cmake kdePackages.extra-cmake-modules pkg-config ];
  buildInputs = [
    kdePackages.kwin
    kdePackages.qtbase
    kdePackages.qtdeclarative
    kdePackages.kconfig
    kdePackages.kcoreaddons
    kdePackages.kwindowsystem
    libdrm libepoxy wayland
  ];
  dontWrapQtApps = true;
  doCheck = true;

  meta = {
    description = "Keep a desktop output repainting while leaving selected apps free to use VRR";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };
}
