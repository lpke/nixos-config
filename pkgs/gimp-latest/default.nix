{
  lib,
  callPackage,
  fetchurl,
  runCommand,
  appimageTools,
  kdePackages,
  darktable,
  gimpPlugins,
}:

let
  pname = "gimp";
  version = "3.2.4";
  appmenuGtkModule = callPackage ../appmenu-gtk-module {};
  kdeGtkConfig = kdePackages.kde-gtk-config;
  resynthesizer = gimpPlugins.resynthesizer;
  appimageResynthesizer = runCommand "${resynthesizer.name}-appimage" {} ''
    cp -a ${resynthesizer} "$out"
    chmod -R u+w "$out"
    find "$out/lib/gimp/3.0/plug-ins" -name '*.scm' \
      -exec sed -i '1s|^#!.*$|#!/usr/bin/env gimp-script-fu-interpreter-3.0|' {} +
    find "$out/lib/gimp/3.0/plug-ins" -name '*.scm' -exec chmod +x {} +
  '';

  src = fetchurl {
    url = "https://download.gimp.org/gimp/v${lib.versions.majorMinor version}/linux/GIMP-${version}-x86_64.AppImage";
    hash = "sha256-8c5txnHvHEqth6DbnXRi6MqcC1+JlFYzeAPGujLQur4=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;

    postExtract = ''
      substituteInPlace $out/AppRun \
        --replace-fail \
          'export XDG_DATA_DIRS="''${APPDIR}/usr/share/:$XDG_DATA_DIRS"' \
          'export XDG_DATA_DIRS="''${APPDIR}/usr/share/:${appmenuGtkModule}/share/gsettings-schemas/${appmenuGtkModule.name}:$XDG_DATA_DIRS"' \
        --replace-fail \
          'export GTK_PATH="''${APPDIR}/usr/lib/x86_64-linux-gnu/gtk-3.0"' \
          'export GTK_PATH="${appmenuGtkModule}/lib/gtk-3.0:${kdeGtkConfig}/lib/gtk-3.0:''${APPDIR}/usr/lib/x86_64-linux-gnu/gtk-3.0"' \
        --replace-fail \
          'export GTK_MODULES=""' \
          'export GTK_MODULES="appmenu-gtk-module"' \
        --replace-fail \
          'exec "$APPDIR"/usr/bin/org.gimp.GIMP.Stable "$@"' \
          'export GDK_BACKEND=x11
export UBUNTU_MENUPROXY=1
exec "$APPDIR"/usr/bin/org.gimp.GIMP.Stable "$@"'

      cat >> "$out/usr/etc/gimp/3.0/gimprc" <<'EOF'

(plug-in-path "${appimageResynthesizer}/lib/gimp/3.0/plug-ins:''${gimp_dir}/plug-ins:''${gimp_plug_in_dir}/plug-ins")
EOF

      cat > "$out/usr/bin/darktable" <<EOF
#!/bin/sh
unset LD_PRELOAD
exec ${darktable}/bin/darktable "\$@"
EOF
      chmod +x "$out/usr/bin/darktable"

      cat > "$out/usr/bin/darktable-cli" <<EOF
#!/bin/sh
unset LD_PRELOAD
exec ${darktable}/bin/darktable-cli "\$@"
EOF
      chmod +x "$out/usr/bin/darktable-cli"
    '';
  };
in
appimageTools.wrapAppImage {
  inherit pname version;
  src = appimageContents;

  extraPkgs = pkgs: [
    appmenuGtkModule
    kdeGtkConfig
  ];

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/org.gimp.GIMP.Stable.desktop \
      $out/share/applications/org.gimp.GIMP.Stable.desktop
    install -Dm444 ${appimageContents}/org.gimp.GIMP.Stable.svg \
      $out/share/icons/hicolor/scalable/apps/org.gimp.GIMP.Stable.svg

    substituteInPlace $out/share/applications/org.gimp.GIMP.Stable.desktop \
      --replace-fail "Name=GNU Image Manipulation Program" "Name=GIMP" \
      --replace-fail "Exec=org.gimp.GIMP.Stable %U" "Exec=gimp %U" \
      --replace-fail "TryExec=org.gimp.GIMP.Stable" "TryExec=gimp"
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "GNU Image Manipulation Program, latest stable official AppImage";
    homepage = "https://www.gimp.org/";
    changelog = "https://www.gimp.org/news/";
    license = lib.licenses.gpl3Plus;
    mainProgram = "gimp";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
