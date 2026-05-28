{ lib, withApp }:

let
  konsoleYakuake = (withApp "konsole-yakuake").dataFile;
  systemMonitor = (withApp "system-monitor").dataFile;

in lib.foldl' lib.recursiveUpdate {} [
    # merged-in configs:
    konsoleYakuake
    systemMonitor
    # all other configs:
    {
      #...
    }]
