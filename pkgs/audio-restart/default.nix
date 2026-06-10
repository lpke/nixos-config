{ pkgs, commandName ? "ars" }:

pkgs.writeShellApplication {
  name = commandName;
  runtimeInputs = with pkgs; [
    coreutils
    gnugrep
    gnused
    procps
    systemd
    wireplumber
  ];
  text = builtins.readFile ./audio-restart.sh;
}
