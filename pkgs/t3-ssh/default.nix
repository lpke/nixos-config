{ lib, stdenvNoCC, python3, makeWrapper, systemd, alacritty }:
stdenvNoCC.mkDerivation {
  pname = "t3-ssh";
  version = "1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper ];
  doInstallCheck = true;
  installCheckPhase = ''
    PYTHONPATH="$out/lib/t3-ssh" ${python3}/bin/python -B -c "from t3_ssh import runtime, cli"
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/t3-ssh" "$out/bin"
    cp -r t3_ssh help.md "$out/lib/t3-ssh/"
    makeWrapper ${python3}/bin/python "$out/bin/t3-ssh" \
      --add-flags "-m t3_ssh.cli" \
      --prefix PYTHONPATH : "$out/lib/t3-ssh" \
      --set PYTHONDONTWRITEBYTECODE 1 \
      --prefix PATH : ${lib.makeBinPath [ systemd alacritty ]}
    runHook postInstall
  '';
}
