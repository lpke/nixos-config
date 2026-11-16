{ lib, stdenvNoCC, python3, makeWrapper, krohnkite }:
let
  python = python3.withPackages (ps: [ ps.pyqt6 ]);
in stdenvNoCC.mkDerivation {
  pname = "krohnkite-control";
  version = "1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper ];
  doCheck = true;
  checkPhase = ''
    ${python}/bin/python -B -m unittest -v
  '';
  installPhase = ''
    mkdir -p "$out/lib/krohnkite-control" "$out/bin"
    cp control.py "$out/lib/krohnkite-control/"
    makeWrapper ${python}/bin/python "$out/bin/krohnkite" \
      --add-flags "$out/lib/krohnkite-control/control.py" \
      --set KROHNKITE_PACKAGE ${krohnkite}/share/kwin/scripts/krohnkite \
      --set PYTHONDONTWRITEBYTECODE 1
  '';
  meta.mainProgram = "krohnkite";
}
