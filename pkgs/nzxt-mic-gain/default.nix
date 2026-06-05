{ pkgs, commandName ? "nzxt-mic-gain" }:

pkgs.writeShellApplication {
  name = commandName;
  runtimeInputs = with pkgs; [
    alsa-utils
    coreutils
    gawk
    gnused
  ];
  text = builtins.readFile ./nzxt-mic-gain.sh;
}
