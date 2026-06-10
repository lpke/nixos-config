#!/usr/bin/env bash
set -u

failed=0

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

run() {
  log "run: $*"
  if "$@"; then
    log "ok: $*"
  else
    status=$?
    log "error($status): $*"
    failed=1
  fi
}

unit_exists() {
  systemctl --user list-unit-files "$1" --no-legend 2>/dev/null | grep -q "^$1"
}

restart_optional_unit() {
  unit="$1"
  action="${2:-restart}"

  if unit_exists "$unit"; then
    run systemctl --user "$action" "$unit"
  else
    log "skip: $unit not installed"
  fi
}

kill_chromium_audio_services() {
  log "scan: Chromium/Electron audio service subprocesses"

  matches="$(
    pgrep -u "$(id -u)" -af -- '--utility-sub-type=audio.mojom.AudioService' || true
  )"

  if [ -z "$matches" ]; then
    log "ok: no Chromium/Electron audio service subprocesses found"
    return
  fi

  while IFS= read -r match; do
    pid="${match%% *}"
    command="${match#* }"

    if [ -z "${pid:-}" ]; then
      continue
    fi

    log "terminate: pid=$pid command=$command"
    if kill -TERM "$pid" 2>/dev/null; then
      log "ok: sent TERM to pid=$pid"
    else
      log "error: failed to TERM pid=$pid"
      failed=1
    fi
  done <<< "$matches"
}

log "audio restart begin"

run systemctl --user restart pipewire.service pipewire-pulse.service wireplumber.service

restart_optional_unit audio-volume-lock.service restart
restart_optional_unit nzxt-mic-gain-startup.service start

log "wait: PipeWire graph"
if wpctl status >/dev/null 2>&1; then
  log "ok: PipeWire graph available"
else
  status=$?
  log "error($status): wpctl status failed"
  failed=1
fi

kill_chromium_audio_services

log "audio devices after restart:"
wpctl status 2>&1 | sed -n '/Audio/,/Video/p' || failed=1

if [ "$failed" -eq 0 ]; then
  log "audio restart complete"
else
  log "audio restart complete with errors"
fi

exit "$failed"
