{ pkgs }: kwin:
assert kwin.version == "6.6.5";
kwin.overrideAttrs (old: {
  pname = "kwin-pointer-warp-scale";
  patches = (old.patches or []) ++ [ ./kwin-pointer-warp-scale.patch ];
  buildInputs = (old.buildInputs or []) ++ [ pkgs.kdePackages.kwayland pkgs.kdePackages.kpipewire ];
  nativeCheckInputs = (old.nativeCheckInputs or []) ++ [ pkgs.dbus pkgs.xwayland ];
  cmakeFlags = (old.cmakeFlags or []) ++ [ "-DBUILD_TESTING=ON" ];
  postPatch = (old.postPatch or "") + ''
    substituteInPlace CMakeLists.txt --replace-fail 'add_subdirectory(autotests)' 'add_subdirectory(autotests EXCLUDE_FROM_ALL)'
  '';
  postBuild = (old.postBuild or "") + ''
    cmake --build . --target testPointerConstraints --parallel "$NIX_BUILD_CORES"
  '';
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export XDG_RUNTIME_DIR="$TMPDIR/pb473-test-runtime"
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
    mkdir -p /tmp/.X11-unix
    chmod 1777 /tmp/.X11-unix
    dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- ./bin/testPointerConstraints
    runHook postCheck
  '';
})
