{ writeShellApplication, coreutils, curl, jq, nix }:

writeShellApplication {
  name = "update-t3code";
  runtimeInputs = [ coreutils curl jq nix ];
  text = ''
    # Edit the checkout, never the immutable copy of the pin in the Nix store.
    export T3CODE_NIX_SOURCE="''${T3CODE_NIX_SOURCE:-''${NIXOS_CONFIG_FLAKE:-/etc/nixos}/pkgs/t3code/source.json}"
  '' + builtins.readFile ./update.sh;
}
