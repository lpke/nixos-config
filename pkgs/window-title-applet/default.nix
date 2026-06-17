{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  pname = "plasma6-window-title-applet";
  version = "0.9.0";

  src = fetchFromGitHub {
    owner = "dhruv8sh";
    repo = "plasma6-window-title-applet";
    rev = "v0.9.0";
    hash = "sha256-pFXVySorHq5EpgsBz01vZQ0sLAy2UrF4VADMjyz2YLs=";
  };

  postPatch = ''
    substituteInPlace contents/ui/main.qml \
      --replace-fail "import org.kde.plasma.private.appmenu 1.0 as AppMenuPrivate" ""
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/plasma/plasmoids/org.kde.windowtitle"
    cp -r . "$out/share/plasma/plasmoids/org.kde.windowtitle"

    runHook postInstall
  '';

  meta = {
    description = "Plasma 6 applet that shows the active window title and icon";
    homepage = "https://github.com/dhruv8sh/plasma6-window-title-applet";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
  };
}
