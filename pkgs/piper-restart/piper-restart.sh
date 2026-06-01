set -euo pipefail

export PATH="/run/wrappers/bin:$PATH"

unit="app-libratbag@autostart.service"
piper_log="/tmp/piper-prs.log"
ratbag_log="/tmp/ratbagd-prs.log"

wait_until_gone() {
  local label="$1"
  shift

  for _ in $(seq 1 50); do
    if ! "$@" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done

  echo "Timed out waiting for $label to stop." >&2
  return 1
}

wait_for_bus() {
  for _ in $(seq 1 50); do
    if busctl --system list | grep -q 'org.freedesktop.ratbag1'; then
      return 0
    fi
    sleep 0.1
  done

  echo "Timed out waiting for ratbagd D-Bus service." >&2
  return 1
}

echo "Stopping Piper and ratbagd..."

pkill -f '[p]iper' || true

unit_available=0
if systemctl --user cat "$unit" >/dev/null 2>&1; then
  unit_available=1
  systemctl --user stop "$unit" || true
fi

sudo pkill -x ratbagd || true
sudo pkill -f '[s]udo ratbagd' || true

if ! wait_until_gone "Piper" pgrep -f '[p]iper'; then
  pkill -KILL -f '[p]iper' || true
  wait_until_gone "Piper" pgrep -f '[p]iper'
fi

if ! wait_until_gone "ratbagd" sudo pgrep -x ratbagd; then
  sudo pkill -KILL -x ratbagd || true
  wait_until_gone "ratbagd" sudo pgrep -x ratbagd
fi

if ! wait_until_gone "sudo ratbagd" pgrep -f '[s]udo ratbagd'; then
  sudo pkill -KILL -f '[s]udo ratbagd' || true
  wait_until_gone "sudo ratbagd" pgrep -f '[s]udo ratbagd'
fi

echo "Starting ratbagd..."

if [ "$unit_available" -eq 1 ]; then
  systemctl --user start "$unit"
else
  nohup sudo ratbagd > "$ratbag_log" 2>&1 &
  disown "$!" 2>/dev/null || true
fi

wait_for_bus

echo "Starting Piper..."
rm -f "$piper_log"
nohup piper > "$piper_log" 2>&1 &
disown "$!" 2>/dev/null || true

sleep 0.5
if ! pgrep -f '[p]iper' >/dev/null 2>&1; then
  echo "Piper failed to stay running. See $piper_log." >&2
  exit 1
fi

echo "Piper restart complete."
ratbagctl list || true
