{
  python3,
  writeShellApplication,
}:
let
  python = python3.withPackages (packages: [ packages.dbus-next ]);
in
writeShellApplication {
  name = "xremap-mode-controller";
  runtimeInputs = [ python ];
  text = ''
    exec ${python}/bin/python ${./xremap-mode-controller.py} "$@"
  '';
}
