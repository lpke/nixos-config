{ lib }:

let
  konsoleYakuake = (import ./apps/konsole-yakuake.nix { inherit lib; }).dataFile;

in lib.foldl' lib.recursiveUpdate {} [
    # merged-in configs:
    konsoleYakuake
    # all other configs:
    {
      #...
    }]
