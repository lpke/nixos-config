{ lib
, pkgs
}:

pkgs.stdenv.mkDerivation rec {
  pname = "ksystemstats-custom-sensors";
  version = "2.0.1";

  src = pkgs.fetchFromGitHub {
    owner = "vazh2100";
    repo = "ksystemstats_custom_sensors";
    rev = "v${version}";
    hash = "sha256-O9YINKwq4ZhKyBgkudyEV1njzjxU0aK9/32cDm+oFhw=";
  };

  nativeBuildInputs = [
    pkgs.cmake
    pkgs.kdePackages.extra-cmake-modules
  ];

  buildInputs = [
    pkgs.qt6.qtbase
    pkgs.kdePackages.kcoreaddons
    pkgs.kdePackages.libksysguard
  ];

  dontWrapQtApps = true;

  meta = {
    description = "KSystemStats plugin for file-backed custom sensors";
    homepage = "https://github.com/vazh2100/ksystemstats_custom_sensors";
    platforms = lib.platforms.linux;
  };
}
