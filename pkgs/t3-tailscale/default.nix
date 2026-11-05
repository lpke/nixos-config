{ lib, stdenvNoCC, python3, makeWrapper, systemd, xdg-utils, tailscale }:
stdenvNoCC.mkDerivation {
  pname = "t3-tailscale";
  version = "1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper ];
  doInstallCheck = true;
  installCheckPhase = ''
    PYTHONPATH="$out/lib/t3-tailscale" ${python3}/bin/python -B -c "from t3_tailscale import runtime, cli"
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/t3-tailscale" "$out/bin"
    cp -r t3_tailscale help.txt "$out/lib/t3-tailscale/"
    makeWrapper ${python3}/bin/python "$out/bin/t3-tailscale" \
      --add-flags "-m t3_tailscale.cli" \
      --prefix PYTHONPATH : "$out/lib/t3-tailscale" \
      --set PYTHONDONTWRITEBYTECODE 1 \
      --prefix PATH : ${lib.makeBinPath [ systemd xdg-utils tailscale ]}
    runHook postInstall
  '';
}
