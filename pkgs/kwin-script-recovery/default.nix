{ stdenv, cmake, pkg-config, kdePackages, libdrm, libepoxy, wayland }:
stdenv.mkDerivation {
  pname = "kwin-script-recovery";
  version = "1.0";
  src = ./.;
  nativeBuildInputs = [ cmake kdePackages.extra-cmake-modules pkg-config ];
  buildInputs = [ kdePackages.kwin kdePackages.qtbase kdePackages.qtdeclarative kdePackages.kconfig kdePackages.kcoreaddons kdePackages.kwindowsystem libdrm libepoxy wayland ];
  dontWrapQtApps = true;
}
