set -euo pipefail

card="MIC"
control="Mic"

if ! output="$(amixer -c "$card" sget "$control" 2>&1)"; then
  echo "$output" >&2
  exit 1
fi

line="$(sed -n '/^[[:space:]]*Mono:/ { s/^[[:space:]]*//; p; q; }' <<< "$output")"
limits="$(sed -n 's/^[[:space:]]*Limits: Capture //p' <<< "$output" | head -n1)"

echo "NZXT USB MIC hardware gain"
echo "card: $card"
echo "control: $control"
if [ -n "$limits" ]; then
  echo "raw range: $limits"
fi
echo "dB range: +0.05dB to +79.89dB"
echo "current: $line"
