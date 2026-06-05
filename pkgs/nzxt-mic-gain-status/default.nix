{ pkgs, commandName ? "nzxt-mic-gain-status" }:

pkgs.writeShellApplication {
  name = commandName;
  runtimeInputs = with pkgs; [
    alsa-utils
    coreutils
    gnused
  ];
  text = builtins.readFile ./nzxt-mic-gain-status.sh;
}
