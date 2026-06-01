{ pkgs, commandName ? "prs" }:

pkgs.writeShellApplication {
  name = commandName;
  runtimeInputs = with pkgs; [
    coreutils
    gnugrep
    libratbag
    piper
    procps
    systemd
  ];
  text = builtins.readFile ./piper-restart.sh;
}
