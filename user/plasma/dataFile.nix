{ lib }:

let
  konsoleYakuake = (import ./apps/konsole-yakuake.nix { inherit lib; }).dataFile;
  systemMonitor = (import ./apps/system-monitor.nix { inherit lib; }).dataFile;

in lib.foldl' lib.recursiveUpdate {} [
    # merged-in configs:
    konsoleYakuake
    systemMonitor
    # all other configs:
    {
      #...
    }]
