#!/usr/bin/env bash
set -euo pipefail

card="${NZXT_MIC_CARD:-MIC}"
control="${NZXT_MIC_CONTROL:-Mic}"
command="$(basename "$0")"
extended_range_maxes="${NZXT_MIC_EXTENDED_RANGE_MAXES:-233 255}"
compact_range_max="${NZXT_MIC_COMPACT_RANGE_MAX:-100}"
extended_range_gain_percent="${NZXT_MIC_EXTENDED_RANGE_GAIN_PERCENT:-1}"
compact_range_gain_percent="${NZXT_MIC_COMPACT_RANGE_GAIN_PERCENT:-100}"
fallback_gain_percent="${NZXT_MIC_FALLBACK_GAIN_PERCENT:-100}"

usage() {
  cat <<EOF
${command}: show or set NZXT USB MIC hardware gain

Usage:
  ${command}
  ${command} --status
  ${command} auto
  ${command} <percent>
  ${command} --set <percent>

Percent values are numbers 0-100 (decimals allowed). Very small values round to
the nearest ALSA raw step, so 0.1 may still land on the same hardware step.

Mode-aware restore:
  auto chooses the configured gain for the detected NZXT USB MIC mixer range.
EOF
}

parse_limits() {
  sed -n 's/^[[:space:]]*Limits: Capture //p' <<< "$1" | head -n1
}

parse_mono_line() {
  sed -n '/^[[:space:]]*Mono: / { s/^[[:space:]]*//; p; q; }' <<< "$1"
}

parse_raw_value() {
  sed -n 's/^.*Capture[[:space:]]\+\([0-9][0-9]*\)[[:space:]]\+\[.*/\1/p' <<< "$1"
}

parse_displayed_percent() {
  sed -n 's/^.*\[\([0-9][0-9]*\(\.[0-9][0-9]*\)\?\)%\].*$/\1/p' <<< "$1"
}

parse_min() {
  sed -n 's/^\([0-9-]*\) - \([0-9]*\).*/\1/p' <<< "$1"
}

parse_max() {
  sed -n 's/^[0-9-]* - \([0-9]*\).*/\1/p' <<< "$1"
}

mode_for_max() {
  max="$1"

  for expected_max in $extended_range_maxes; do
    if [ "$max" = "$expected_max" ]; then
      echo "extended-range"
      return
    fi
  done

  if [ "$max" = "$compact_range_max" ]; then
    echo "compact-range"
    return
  fi

  echo "fallback"
}

mode_description() {
  mode="$1"
  max="$2"

  case "$mode" in
    extended-range)
      echo "extended-range (expected high-resolution NZXT state, max=$max)"
      ;;
    compact-range)
      echo "compact-range (100-step NZXT state, max=$max)"
      ;;
    *)
      echo "fallback (unexpected NZXT mixer range, max=$max)"
      ;;
  esac
}

gain_for_mode() {
  mode="$1"

  case "$mode" in
    extended-range)
      echo "$extended_range_gain_percent"
      ;;
    compact-range)
      echo "$compact_range_gain_percent"
      ;;
    *)
      echo "$fallback_gain_percent"
      ;;
  esac
}

get_output() {
  if ! output="$(amixer -c "$card" sget "$control" 2>&1)"; then
    echo "$output" >&2
    return 1
  fi
  printf '%s\n' "$output"
}

set_gain_percent() {
  value="${1:-}"
  value="${value%\%}"
  max="$2"

  if [ -z "$value" ] || [[ ! "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Invalid percent: $1" >&2
    usage
    exit 2
  fi

  if awk -v v="$value" 'BEGIN { exit !((v >= 0) && (v <= 100)) }'; then
    :
  else
    echo "Percent must be between 0 and 100: $value" >&2
    exit 2
  fi

  raw="$(awk -v v="$value" -v max="$max" 'BEGIN { v = v + 0; raw = int((v * max / 100) + 0.5); if (raw < 0) raw = 0; if (raw > max) raw = max; if (v > 0 && raw == 0) raw = 1; print raw }')"

  amixer -c "$card" sset "$control" "$raw" >/dev/null
}

print_status() {
  output="$(get_output)"

  line="$(parse_mono_line "$output")"
  limits="$(parse_limits "$output")"
  raw="$(parse_raw_value "$line")"
  displayed_percent="$(parse_displayed_percent "$line")"
  if [ -n "$limits" ] && [ -n "$raw" ]; then
    min="$(parse_min "$limits")"
    max="$(parse_max "$limits")"
  else
    min=""
    max=""
  fi

  computed_percent=""
  if [ -n "$min" ] && [ -n "$max" ] && [ -n "$raw" ]; then
    computed_percent="$(awk -v raw="$raw" -v min="$min" -v max="$max" 'BEGIN { if (max == min) { printf "0.00"; } else { printf "%.2f", ((raw - min) * 100.0 / (max - min)); } }')"
  fi

  mode=""
  mode_gain=""
  if [ -n "$max" ]; then
    mode="$(mode_for_max "$max")"
    mode_gain="$(gain_for_mode "$mode")"
  fi

  echo "NZXT USB MIC hardware gain"
  echo "card: $card"
  echo "control: $control"
  if [ -n "$limits" ]; then
    echo "raw range: $limits"
  fi
  if [ -n "$mode" ]; then
    echo "detected mode: $(mode_description "$mode" "$max")"
    echo "configured gain for mode: ${mode_gain}%"
  fi
  echo "current: $line"
  if [ -n "$displayed_percent" ]; then
    echo "percent (driver): ${displayed_percent}%"
  fi
  if [ -n "$computed_percent" ]; then
    echo "percent (raw step): ${computed_percent}%"
  fi
  if [ -n "$raw" ]; then
    echo "raw value: $raw"
  fi
  echo "configured gains:"
  echo "  extended-range maxes (${extended_range_maxes}): ${extended_range_gain_percent}%"
  echo "  compact-range max (${compact_range_max}): ${compact_range_gain_percent}%"
  echo "  fallback: ${fallback_gain_percent}%"
}

set_gain() {
  output="$(get_output)"
  limits="$(parse_limits "$output")"
  if [ -z "$limits" ]; then
    echo "Could not parse capture limits for ${card}/${control}." >&2
    exit 1
  fi

  min="$(parse_min "$limits")"
  max="$(parse_max "$limits")"
  if [ "$min" -ne 0 ]; then
    echo "Unexpected non-zero min gain for ${card}/${control}: $min" >&2
    exit 1
  fi

  set_gain_percent "$1" "$max"
  print_status
}

set_auto_gain() {
  output="$(get_output)"
  limits="$(parse_limits "$output")"
  if [ -z "$limits" ]; then
    echo "Could not parse capture limits for ${card}/${control}." >&2
    exit 1
  fi

  min="$(parse_min "$limits")"
  max="$(parse_max "$limits")"
  if [ "$min" -ne 0 ]; then
    echo "Unexpected non-zero min gain for ${card}/${control}: $min" >&2
    exit 1
  fi

  mode="$(mode_for_max "$max")"
  target="$(gain_for_mode "$mode")"
  echo "NZXT USB MIC detected mode: $(mode_description "$mode" "$max")"
  echo "Applying configured gain for mode: ${target}%"
  set_gain_percent "$target" "$max"
  print_status
}

case "${1:-}" in
  ""|--status|status)
    print_status
    ;;
  auto|--auto|restore|--restore|--set-auto)
    set_auto_gain
    ;;
  --set|set)
    if [ "$#" -ne 2 ] || [ "${2:-}" = "" ]; then
      usage
      exit 2
    fi
    set_gain "$2"
    ;;
  --help|-h|help)
    usage
    ;;
  *)
    if [ "$#" -eq 1 ]; then
      set_gain "$1"
    else
      usage >&2
      exit 2
    fi
esac
