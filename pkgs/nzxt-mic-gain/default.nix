{
  pkgs,
  commandName ? "nzxt-mic-gain",
  extendedRangeMaxes ? [ 233 255 ],
  compactRangeMax ? 100,
  extendedRangeGainPercent ? 1,
  compactRangeGainPercent ? 100,
  fallbackGainPercent ? 100,
}:

let
  extendedRangeMaxesString = builtins.concatStringsSep " " (map builtins.toString extendedRangeMaxes);
in

pkgs.writeShellApplication {
  name = commandName;
  runtimeInputs = with pkgs; [
    alsa-utils
    coreutils
    gawk
    gnused
  ];
  text = ''
    export NZXT_MIC_EXTENDED_RANGE_MAXES="${extendedRangeMaxesString}"
    export NZXT_MIC_COMPACT_RANGE_MAX="${toString compactRangeMax}"
    export NZXT_MIC_EXTENDED_RANGE_GAIN_PERCENT="${toString extendedRangeGainPercent}"
    export NZXT_MIC_COMPACT_RANGE_GAIN_PERCENT="${toString compactRangeGainPercent}"
    export NZXT_MIC_FALLBACK_GAIN_PERCENT="${toString fallbackGainPercent}"

  '' + builtins.readFile ./nzxt-mic-gain.sh;
}
