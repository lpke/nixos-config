{ pkgs }:
base:
let
  python = pkgs.python3.withPackages (ps: [ ps.pyqt6 ]);
  fonts = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
in
base.overrideAttrs (old: {
  patches = (old.patches or []) ++ [ ./center-compact-task-icons.patch ];
  postPatch = (old.postPatch or "") + ''
    (
      export XDG_CACHE_HOME="$TMPDIR/task-icons-cache"
      export XDG_RUNTIME_DIR="$TMPDIR/task-icons-runtime"
      export FONTCONFIG_FILE="${fonts}"
      export QT_PLUGIN_PATH="${pkgs.qt6.qtbase}/${pkgs.qt6.qtbase.qtPluginPrefix}:${pkgs.qt6.qtsvg}/${pkgs.qt6.qtbase.qtPluginPrefix}"
      mkdir -p "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
      chmod 700 "$XDG_RUNTIME_DIR"
      for scale in 1 1.25 2; do
        QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_SCALE_FACTOR="$scale" \
          ${python}/bin/python -B ${./test_rendering.py} applets/taskmanager/qml/Task.qml \
          ${pkgs.kdePackages.kirigami.unwrapped}/lib/qt-6/qml
      done
    )
  '';
})
