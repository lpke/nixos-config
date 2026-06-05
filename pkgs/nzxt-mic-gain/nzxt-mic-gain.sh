#!/usr/bin/env bash
set -euo pipefail

card="${NZXT_MIC_CARD:-MIC}"
control="${NZXT_MIC_CONTROL:-Mic}"
command="$(basename "$0")"

usage() {
  cat <<EOF
${command}: show or set NZXT USB MIC hardware gain

Usage:
  ${command}
  ${command} --status
  ${command} <percent>
  ${command} --set <percent>

Percent values are numbers 0-100 (decimals allowed). Very small values round to
the nearest ALSA raw step, so 0.1 may still land on the same hardware step.
EOF
}

print_status() {
  if ! output="$(amixer -c "$card" sget "$control" 2>&1)"; then
    echo "$output" >&2
    exit 1
  fi

  line="$(sed -n '/^[[:space:]]*Mono: / { s/^[[:space:]]*//; p; q; }' <<< "$output")"
  limits="$(sed -n 's/^[[:space:]]*Limits: Capture //p' <<< "$output" | head -n1)"
  raw="$(sed -n 's/^.*Capture[[:space:]]\+\([0-9][0-9]*\)[[:space:]]\+\[.*/\1/p' <<< "$line")"
  displayed_percent="$(sed -n 's/^.*\[\([0-9][0-9]*\(\.[0-9][0-9]*\)\?\)%\].*$/\1/p' <<< "$line")"
  if [ -n "$limits" ] && [ -n "$raw" ]; then
    min="$(sed -n 's/^\([0-9-]*\) - \([0-9]*\).*/\1/p' <<< "$limits")"
    max="$(sed -n 's/^[0-9-]* - \([0-9]*\).*/\1/p' <<< "$limits")"
  else
    min=""
    max=""
  fi

  computed_percent=""
  if [ -n "$min" ] && [ -n "$max" ] && [ -n "$raw" ]; then
    computed_percent="$(awk -v raw="$raw" -v min="$min" -v max="$max" 'BEGIN { if (max == min) { printf "0.00"; } else { printf "%.2f", ((raw - min) * 100.0 / (max - min)); } }')"
  fi

  echo "NZXT USB MIC hardware gain"
  echo "card: $card"
  echo "control: $control"
  if [ -n "$limits" ]; then
    echo "raw range: $limits"
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
}

set_gain() {
  get_limits() {
    amixer -c "$card" sget "$control" 2>/dev/null | awk '
      /^[[:space:]]*Limits:/ {
        n = 0
        for (i = 1; i <= NF; i++) {
          if ($i ~ /^-?[0-9]+$/) {
            nums[++n] = $i
          }
        }
        if (n >= 2) {
          print nums[n-1], nums[n]
          exit
        }
      }
    '
  }

  value="${1:-}"
  value="${value%\%}"

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

  limits="$(get_limits)"
  if [ -z "$limits" ]; then
    echo "Could not parse capture limits for ${card}/${control}." >&2
    exit 1
  fi

  read -r min max <<< "$limits"
  if [ "$min" -ne 0 ]; then
    echo "Unexpected non-zero min gain for ${card}/${control}: $min" >&2
    exit 1
  fi

  raw="$(awk -v v="$value" -v max="$max" 'BEGIN { v = v + 0; raw = int((v * max / 100) + 0.5); if (raw < 0) raw = 0; if (raw > max) raw = max; if (v > 0 && raw == 0) raw = 1; print raw }')"

  amixer -c "$card" sset "$control" "$raw"
  print_status
}

case "${1:-}" in
  ""|--status|status)
    print_status
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
