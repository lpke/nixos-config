#!/usr/bin/env bash
set -euo pipefail

routing_config="${AUDIO_ROUTING_CONFIG:?}"
locks_config="${AUDIO_LOCKS_CONFIG:?}"
gains_config="${AUDIO_GAINS_CONFIG:?}"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
locks_disabled_file="$runtime_dir/audio-locks-disabled"
gains_disabled_file="$runtime_dir/audio-gains-disabled"
gains_override_dir="$runtime_dir/audio-gains-overrides"

main_help() {
  cat <<'EOF'
audio: custom audio controls

Usage:
  audio status
  audio list [--pipewire|--wireplumber]
  audio restart
  audio loopback <command>
  audio locks <command>
  audio gain <command>
  audio help

Commands:
  status      Readable overview of custom audio state.
  list        List PipeWire node names and WirePlumber device names.
  restart     Restart PipeWire stack and custom audio services.
  loopback    Manage configured PipeWire loopbacks.
  locks       Manage configured PipeWire volume locks.
  gain        Manage configured ALSA hardware gain targets.

Help:
  audio <command> help
  audio <command> <subcommand> help
EOF
}

status_help() {
  cat <<'EOF'
audio status: readable overview of custom audio state

Usage:
  audio status
  audio status help
EOF
}

list_help() {
  cat <<'EOF'
audio list: list runtime audio identifiers

Usage:
  audio list
  audio list --pipewire
  audio list --wireplumber
  audio list help

Options:
  --pipewire       Show only PipeWire node.name values.
  --wireplumber   Show only WirePlumber device.name values.
EOF
}

restart_help() {
  cat <<'EOF'
audio restart: restart custom audio stack

Usage:
  audio restart
  audio restart help
EOF
}

loopback_help() {
  cat <<'EOF'
audio loopback: managed PipeWire loopbacks

Usage:
  audio loopback status
  audio loopback list
  audio loopback rebind
  audio loopback toggle <id-or-name>
  audio loopback on <id-or-name>
  audio loopback off <id-or-name>
  audio loopback status help
  audio loopback list help
  audio loopback <command> help

Matching:
  IDs match first. If no ID matches, configured descriptions, inputs, and outputs
  are matched case-insensitively.

Example:
  audio loopback toggle cubilux
  audio loopback toggle "Cubilux"
EOF
}

locks_help() {
  cat <<'EOF'
audio locks: PipeWire software volume locks

Usage:
  audio locks status
  audio locks list
  audio locks lock <id>
  audio locks unlock <id>
  audio locks watch
  audio locks status help
  audio locks list help
  audio locks <command> help

Commands:
  status    Show configured locks and runtime state.
  list      Alias for status.
  lock      Enable runtime enforcement for a configured lock and apply it now.
  unlock    Disable runtime enforcement until the lock is re-enabled.
  watch     Run lock daemon loop.
EOF
}

gain_help() {
  cat <<'EOF'
audio gain: ALSA hardware gain targets

Usage:
  audio gain status
  audio gain set <id> <percent|auto>
  audio gain enable <id>
  audio gain disable <id>
  audio gain watch
  audio gain apply-all
  audio gain status help
  audio gain <command> help

Commands:
  status      Show configured gain targets and runtime state.
  set         Override one gain target.
  enable      Enable runtime enforcement and clear override.
  disable     Disable runtime enforcement.
  watch       Run gain daemon loop.
  apply-all   Apply all enabled gain targets once.

Notes:
  auto is supported for NZXT USB MIC gain targets and selects the configured
  gain for the currently detected ALSA mixer range.
EOF
}

loopback_rebind_help() {
  cat <<'EOF'
audio loopback rebind: restart active managed loopbacks

Usage:
  audio loopback rebind
  audio loopback rebind help
EOF
}

loopback_state_help() {
  cat <<'EOF'
audio loopback toggle/on/off: change a managed loopback runtime state

Usage:
  audio loopback toggle <id-or-name>
  audio loopback on <id-or-name>
  audio loopback off <id-or-name>
  audio loopback toggle help
EOF
}

locks_lock_help() {
  cat <<'EOF'
audio locks lock/unlock: change runtime lock enforcement

Usage:
  audio locks lock <id>
  audio locks unlock <id>
  audio locks lock help
EOF
}

gain_set_help() {
  cat <<'EOF'
audio gain set: override a hardware gain target

Usage:
  audio gain set <id> <percent|auto>
  audio gain set help
EOF
}

gain_state_help() {
  cat <<'EOF'
audio gain enable/disable: change runtime gain enforcement

Usage:
  audio gain enable <id>
  audio gain disable <id>
  audio gain enable help
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

is_help_arg() {
  case "${1:-}" in
    help|--help|-h)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

has_help_arg() {
  for arg in "$@"; do
    if is_help_arg "$arg"; then
      return 0
    fi
  done
  return 1
}

service_state() {
  state="$(systemctl --user is-active "$1" 2>/dev/null || true)"
  if [ -z "$state" ]; then
    echo "unknown"
  else
    echo "$state"
  fi
}

unit_exists() {
  systemctl --user list-unit-files "$1" --no-legend 2>/dev/null | grep -q "^$1"
}

node_id_by_name() {
  pw-dump 2>/dev/null | jq -r --arg node_name "$1" '
    .[]
    | select(.type == "PipeWire:Interface:Node")
    | select(.info.props."node.name" == $node_name)
    | .id
  ' | head -n1
}

node_description_by_ref() {
  wpctl inspect "$1" 2>/dev/null \
    | sed -n 's/^  \* node.description = "\(.*\)"$/\1/p' \
    | head -n1
}

list_pipewire_nodes() {
  echo "PipeWire nodes:"
  nodes="$(
    pw-dump 2>/dev/null | jq -r '
      .[]
      | select(.type == "PipeWire:Interface:Node")
      | .info.props as $p
      | [
          ($p."node.name" // "-"),
          ($p."media.class" // "-"),
          ($p."node.description" // "-")
        ]
      | @tsv
    ' | sort || true
  )"
  if [ -z "$nodes" ]; then
    echo "  none"
  else
    first=true
    printf '%s\n' "$nodes" | while IFS=$'\t' read -r name media_class description; do
      if [ "$first" = "true" ]; then
        first=false
      else
        echo
      fi
      printf '  %s:\n' "$name"
      printf '    class: %s\n' "$media_class"
      printf '    description: %s\n' "$description"
    done
  fi
}

list_wireplumber_devices() {
  echo "WirePlumber devices:"
  devices="$(
    pw-dump 2>/dev/null | jq -r '
      .[]
      | select(.type == "PipeWire:Interface:Device")
      | .info.props as $p
      | [
          ($p."device.name" // "-"),
          ($p."device.description" // $p."device.nick" // "-")
        ]
      | @tsv
    ' | sort || true
  )"
  if [ -z "$devices" ]; then
    echo "  none"
  else
    first=true
    printf '%s\n' "$devices" | while IFS=$'\t' read -r name description; do
      if [ "$first" = "true" ]; then
        first=false
      else
        echo
      fi
      printf '  %s:\n' "$name"
      printf '    description: %s\n' "$description"
    done
  fi
}

audio_list() {
  if has_help_arg "$@"; then
    list_help
    return
  fi

  case "${1:-}" in
    "")
      [ -z "${2:-}" ] || {
        list_help
        exit 2
      }
      list_pipewire_nodes
      echo
      list_wireplumber_devices
      ;;
    --pipewire)
      [ -z "${2:-}" ] || {
        list_help
        exit 2
      }
      list_pipewire_nodes
      ;;
    --wireplumber)
      [ -z "${2:-}" ] || {
        list_help
        exit 2
      }
      list_wireplumber_devices
      ;;
    *)
      list_help
      exit 2
      ;;
  esac
}

target_label() {
  target="$1"
  case "$target" in
    @DEFAULT_AUDIO_SOURCE@|@DEFAULT_AUDIO_SINK@)
      label="$(node_description_by_ref "$target" || true)"
      ;;
    *)
      id="$(node_id_by_name "$target" || true)"
      if [ -n "$id" ]; then
        label="$(node_description_by_ref "$id" || true)"
      else
        label=""
      fi
      ;;
  esac

  if [ -n "$label" ]; then
    echo "$label"
  else
    echo "$target"
  fi
}

target_ref_label() {
  target="$1"
  case "$target" in
    DEFAULT_SOURCE|@DEFAULT_AUDIO_SOURCE@)
      echo "default input"
      ;;
    DEFAULT_SINK|@DEFAULT_AUDIO_SINK@)
      echo "default output"
      ;;
    RAW:*)
      printf 'raw %s\n' "${target#RAW:}"
      ;;
    "")
      echo ""
      ;;
    *)
      echo "$target"
      ;;
  esac
}

target_display() {
  runtime_target="$1"
  config_target="$2"
  label="$(target_label "$runtime_target")"
  ref="$(target_ref_label "$config_target")"

  if [ -n "$ref" ] && [ "$ref" != "$label" ]; then
    printf '%s (%s)\n' "$label" "$ref"
  else
    printf '%s\n' "$label"
  fi
}

display_label() {
  label="$1"
  printf '%s\n' "${label// -> / to }"
}

indent() {
  sed '/^$/!s/^/  /'
}

disabled_contains() {
  file="$1"
  item="$2"
  [ -f "$file" ] && grep -Fxq "$item" "$file"
}

disable_item() {
  file="$1"
  item="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if ! grep -Fxq "$item" "$file"; then
    printf '%s\n' "$item" >> "$file"
  fi
}

enable_item() {
  file="$1"
  item="$2"
  mkdir -p "$(dirname "$file")"
  if [ ! -f "$file" ]; then
    return
  fi
  tmp="$file.tmp.$$"
  grep -Fxv "$item" "$file" > "$tmp" || true
  mv "$tmp" "$file"
}

runtime_word() {
  config_enabled="$1"
  disabled_file="$2"
  item="$3"

  if [ "$config_enabled" != "true" ]; then
    echo "config-disabled"
  elif disabled_contains "$disabled_file" "$item"; then
    echo "runtime-disabled"
  else
    echo "enabled"
  fi
}

configured_loopbacks() {
  jq -r '.loopbacks | to_entries[] | [
    .key,
    (.value.enable | tostring),
    (.value.startByDefault | tostring),
    .value.description,
    .value.service,
    .value.inputTarget,
    .value.outputTarget,
    .value.input,
    .value.output
  ] | @tsv' "$routing_config"
}

on_off() {
  if [ "$1" = "true" ]; then
    echo "on"
  else
    echo "off"
  fi
}

loopback_ids() {
  jq -r '.loopbacks | keys[]' "$routing_config"
}

loopback_match() {
  query="$1"

  if jq -e --arg id "$query" '.loopbacks[$id] != null' "$routing_config" >/dev/null; then
    echo "$query"
    return
  fi

  matches="$(
    jq -r --arg query "$query" '
      ($query | ascii_downcase) as $q
      | .loopbacks
      | to_entries[]
      | select(.value.enable == true)
      | select(
          (.key | ascii_downcase | contains($q))
          or (.value.description | ascii_downcase | contains($q))
          or (.value.input | ascii_downcase | contains($q))
          or (.value.output | ascii_downcase | contains($q))
        )
      | .key
    ' "$routing_config"
  )"

  count="$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ "$count" = "0" ]; then
    lower_query="${query,,}"
    runtime_matches="$(
      configured_loopbacks | while IFS=$'\t' read -r id enabled _start_by_default description _service input_target output_target _input _output; do
        if [ "$enabled" != "true" ]; then
          continue
        fi
        input_label="$(target_label "$input_target")"
        output_label="$(target_label "$output_target")"
        haystack="${id} ${description} ${input_label} ${output_label}"
        if [[ "${haystack,,}" == *"$lower_query"* ]]; then
          echo "$id"
        fi
      done
    )"
    matches="$runtime_matches"
    count="$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')"
  fi

  case "$count" in
    0)
      die "no loopback matches: $query"
      ;;
    1)
      printf '%s\n' "$matches" | sed '/^$/d'
      ;;
    *)
      echo "ambiguous loopback match: $query" >&2
      printf '%s\n' "$matches" | sed '/^$/d; s/^/  /' >&2
      exit 1
      ;;
  esac
}

loopback_service() {
  jq -r --arg id "$1" '.loopbacks[$id].service // empty' "$routing_config"
}

loopback_config_enabled() {
  jq -r --arg id "$1" '.loopbacks[$id].enable // false' "$routing_config"
}

loopback_item_status() {
  wanted_id="$1"
  configured_loopbacks | while IFS=$'\t' read -r id enabled start_by_default description service input_target output_target input output; do
    if [ "$id" != "$wanted_id" ]; then
      continue
    fi
    state="$(service_state "$service")"
    printf '%s: config=%s, default=%s, runtime=%s\n' "$id" "$enabled" "$(on_off "$start_by_default")" "$state"
    printf '  label: %s\n' "$(display_label "$description")"
    printf '  input: %s\n' "$(target_display "$input_target" "$input")"
    printf '  output: %s\n' "$(target_display "$output_target" "$output")"
    return
  done
}

loopback_list() {
  ids="$(loopback_ids)"
  if [ -z "$ids" ]; then
    echo "none"
    return
  fi

  first=true
  printf '%s\n' "$ids" | while read -r id; do
    if [ "$first" = "true" ]; then
      first=false
    else
      echo
    fi
    loopback_item_status "$id"
  done
}

loopback_status() {
  echo "configured loopbacks:"
  loopback_list | indent
  echo
  echo "runtime loopback nodes:"
  unmanaged="$(
    pw-dump 2>/dev/null | jq -r '
      .[]
      | select(.type == "PipeWire:Interface:Node")
      | .info.props as $p
      | select((($p."node.link-group" // $p."node.group" // "") | startswith("loopback-")) or (($p."node.name" // "") | test("loopback")))
      | [
          ($p."node.name" // "-"),
          ($p."media.class" // "-"),
          ($p."node.description" // "-")
        ]
      | @tsv
    ' || true
  )"
  if [ -z "$unmanaged" ]; then
    echo "  none"
  else
    first=true
    printf '%s\n' "$unmanaged" | while IFS=$'\t' read -r name media_class description; do
      if [ "$first" = "true" ]; then
        first=false
      else
        echo
      fi
      printf '  %s:\n' "$name"
      printf '    class: %s\n' "$media_class"
      printf '    description: %s\n' "$description"
    done
  fi
}

loopback_set_state() {
  action="$1"
  query="$2"
  id="$(loopback_match "$query")"
  enabled="$(loopback_config_enabled "$id")"
  if [ "$enabled" != "true" ]; then
    die "loopback is config-disabled: $id"
  fi

  service="$(loopback_service "$id")"
  case "$action" in
    on)
      systemctl --user start "$service"
      ;;
    off)
      systemctl --user stop "$service"
      ;;
    toggle)
      if systemctl --user is-active --quiet "$service"; then
        systemctl --user stop "$service"
      else
        systemctl --user start "$service"
      fi
      ;;
    *)
      die "unknown loopback action: $action"
      ;;
  esac

  loopback_item_status "$id"
}

loopback_active_ids() {
  configured_loopbacks | while IFS=$'\t' read -r id enabled _start_by_default _description service _input_target _output_target _input _output; do
    if [ "$enabled" = "true" ] && systemctl --user is-active --quiet "$service"; then
      echo "$id"
    fi
  done
}

loopback_rebind() {
  active="$(loopback_active_ids || true)"
  services="$(configured_loopbacks | while IFS=$'\t' read -r _id enabled _start_by_default _description service _input_target _output_target _input _output; do
    if [ "$enabled" = "true" ]; then
      echo "$service"
    fi
  done)"

  if [ -n "$services" ]; then
    printf '%s\n' "$services" | while read -r service; do
      systemctl --user stop "$service" 2>/dev/null || true
    done
  fi

  if [ -z "$active" ]; then
    echo "no active managed loopbacks to rebind"
    return
  fi

  printf '%s\n' "$active" | while read -r id; do
    service="$(loopback_service "$id")"
    systemctl --user start "$service"
    echo "rebound: $id ($service)"
  done
}

lock_ids() {
  jq -r '.locks | keys[]' "$locks_config"
}

lock_exists() {
  jq -e --arg id "$1" '.locks[$id] != null' "$locks_config" >/dev/null
}

lock_field() {
  jq -r --arg id "$1" --arg field "$2" '.locks[$id][$field] // empty' "$locks_config"
}

lock_apply() {
  id="$1"
  lock_exists "$id" || die "unknown lock: $id"

  enabled="$(lock_field "$id" enable)"
  if [ "$enabled" != "true" ]; then
    echo "skip: $id config-disabled"
    return
  fi
  if disabled_contains "$locks_disabled_file" "$id"; then
    echo "skip: $id runtime-disabled"
    return
  fi

  node_name="$(lock_field "$id" nodeTarget)"
  volume="$(lock_field "$id" volume)"
  node_id="$(node_id_by_name "$node_name" || true)"
  if [ -z "$node_id" ]; then
    echo "missing: $id node=$node_name" >&2
    return
  fi
  wpctl set-volume -l 1.0 "$node_id" "$volume"
}

locks_apply_all() {
  lock_ids | while read -r id; do
    lock_apply "$id" || true
  done
}

lock_item_status() {
  id="$1"
  enabled="$(lock_field "$id" enable)"
  runtime="$(runtime_word "$enabled" "$locks_disabled_file" "$id")"
  description="$(lock_field "$id" description)"
  node_ref="$(lock_field "$id" nodeName)"
  node_name="$(lock_field "$id" nodeTarget)"
  volume="$(lock_field "$id" volume)"
  node_id="$(node_id_by_name "$node_name" || true)"
  if [ -n "$node_id" ]; then
    current="$(wpctl get-volume "$node_id" 2>/dev/null || true)"
    current="${current#Volume: }"
  else
    current="missing"
  fi
  printf '%s: config=%s, runtime=%s\n' "$id" "$enabled" "$runtime"
  printf '  label: %s\n' "$(display_label "$description")"
  printf '  device: %s\n' "$(target_display "$node_name" "$node_ref")"
  printf '  target volume: %s\n' "$volume"
  printf '  current volume: %s\n' "$current"
}

locks_status() {
  service="$(jq -r '.service' "$locks_config")"
  echo "service: $service, runtime=$(service_state "$service")"
  ids="$(lock_ids)"
  if [ -z "$ids" ]; then
    echo
    echo "none"
    return
  fi

  printf '%s\n' "$ids" | while read -r id; do
    echo
    lock_item_status "$id"
  done
}

locks_watch() {
  delay="$(jq -r '.intervalSeconds' "$locks_config")"
  while true; do
    locks_apply_all
    pactl subscribe 2>/dev/null | while read -r event; do
      case "$event" in
        *" on source "*|*" on sink "*|*" on server "*)
          locks_apply_all
          sleep "$delay"
          ;;
      esac
    done || true
    sleep "$delay"
  done
}

valid_percent() {
  value="${1%\%}"
  [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]] && awk -v v="$value" 'BEGIN { exit !((v >= 0) && (v <= 100)) }'
}

gain_ids() {
  jq -r '.gains | keys[]' "$gains_config"
}

gain_exists() {
  jq -e --arg id "$1" '.gains[$id] != null' "$gains_config" >/dev/null
}

gain_field() {
  jq -r --arg id "$1" --arg field "$2" '.gains[$id][$field] // empty' "$gains_config"
}

gain_override_file() {
  echo "$gains_override_dir/$1"
}

gain_override_value() {
  file="$(gain_override_file "$1")"
  if [ -f "$file" ]; then
    sed -n '1p' "$file"
  fi
}

gain_config_target() {
  id="$1"
  type="$(gain_field "$id" type)"
  if [ "$type" = "nzxt-usb-mic" ]; then
    echo "auto"
  else
    gain_field "$id" defaultGainPercent
  fi
}

gain_effective_target() {
  override="$(gain_override_value "$1")"
  if [ -n "$override" ]; then
    echo "$override"
  else
    gain_config_target "$1"
  fi
}

gain_output() {
  card="$(gain_field "$1" cardTarget)"
  control="$(gain_field "$1" control)"
  if ! output="$(amixer -c "$card" sget "$control" 2>&1)"; then
    echo "$output" >&2
    return 1
  fi
  printf '%s\n' "$output"
}

gain_limits() {
  sed -n 's/^[[:space:]]*Limits: Capture //p' <<< "$1" | head -n1
}

gain_line() {
  sed -n '/^[[:space:]]*Mono: / { s/^[[:space:]]*//; p; q; }' <<< "$1"
}

gain_min() {
  sed -n 's/^\([0-9-]*\) - \([0-9]*\).*/\1/p' <<< "$1"
}

gain_max() {
  sed -n 's/^[0-9-]* - \([0-9]*\).*/\1/p' <<< "$1"
}

gain_raw() {
  sed -n 's/^.*Capture[[:space:]]\+\([0-9][0-9]*\)[[:space:]]\+\[.*/\1/p' <<< "$1"
}

gain_driver_percent() {
  sed -n 's/^.*\[\([0-9][0-9]*\(\.[0-9][0-9]*\)\?\)%\].*$/\1/p' <<< "$1"
}

gain_nzxt_mode() {
  id="$1"
  max="$2"
  extended="$(jq -r --arg id "$id" '.gains[$id].extendedRangeMaxes[]' "$gains_config")"
  while read -r expected; do
    if [ "$max" = "$expected" ]; then
      echo "extended-range"
      return
    fi
  done <<< "$extended"

  compact="$(gain_field "$id" compactRangeMax)"
  if [ "$max" = "$compact" ]; then
    echo "compact-range"
    return
  fi

  echo "fallback"
}

gain_nzxt_target_for_mode() {
  id="$1"
  mode="$2"
  case "$mode" in
    extended-range)
      gain_field "$id" extendedRangeGainPercent
      ;;
    compact-range)
      gain_field "$id" compactRangeGainPercent
      ;;
    *)
      gain_field "$id" fallbackGainPercent
      ;;
  esac
}

gain_percent_to_raw() {
  percent="${1%\%}"
  max="$2"
  awk -v v="$percent" -v max="$max" 'BEGIN {
    raw = int((v * max / 100) + 0.5)
    if (raw < 0) raw = 0
    if (raw > max) raw = max
    if (v > 0 && raw == 0) raw = 1
    print raw
  }'
}

gain_apply_target() {
  id="$1"
  requested="$2"
  gain_exists "$id" || die "unknown gain: $id"

  enabled="$(gain_field "$id" enable)"
  if [ "$enabled" != "true" ]; then
    echo "skip: $id config-disabled"
    return
  fi
  if disabled_contains "$gains_disabled_file" "$id"; then
    echo "skip: $id runtime-disabled"
    return
  fi

  output="$(gain_output "$id")" || return
  limits="$(gain_limits "$output")"
  if [ -z "$limits" ]; then
    echo "missing limits: $id" >&2
    return
  fi
  min="$(gain_min "$limits")"
  max="$(gain_max "$limits")"
  if [ "$min" != "0" ]; then
    echo "unexpected min for $id: $min" >&2
    return
  fi

  type="$(gain_field "$id" type)"
  if [ "$requested" = "auto" ]; then
    if [ "$type" != "nzxt-usb-mic" ]; then
      echo "auto not supported for gain target: $id" >&2
      return
    fi
    mode="$(gain_nzxt_mode "$id" "$max")"
    target="$(gain_nzxt_target_for_mode "$id" "$mode")"
  else
    valid_percent "$requested" || die "gain percent must be 0-100: $requested"
    target="${requested%\%}"
  fi

  raw="$(gain_percent_to_raw "$target" "$max")"
  card="$(gain_field "$id" cardTarget)"
  control="$(gain_field "$id" control)"
  amixer -c "$card" sset "$control" "$raw" >/dev/null
}

gain_apply() {
  id="$1"
  target="$(gain_effective_target "$id")"
  gain_apply_target "$id" "$target"
}

gains_apply_all() {
  gain_ids | while read -r id; do
    gain_apply "$id" || true
  done
}

gain_item_status() {
  id="$1"
  enabled="$(gain_field "$id" enable)"
  runtime="$(runtime_word "$enabled" "$gains_disabled_file" "$id")"
  description="$(gain_field "$id" description)"
  target="$(gain_effective_target "$id")"
  override="$(gain_override_value "$id")"
  target_note=""
  if [ -n "$override" ]; then
    target_note=" (runtime override)"
  fi

  printf '%s: config=%s, runtime=%s\n' "$id" "$enabled" "$runtime"
  printf '  label: %s\n' "$(display_label "$description")"
  printf '  mixer: card=%s, control=%s\n' "$(gain_field "$id" cardTarget)" "$(gain_field "$id" control)"
  printf '  target: %s%s\n' "$target" "$target_note"

  if output="$(gain_output "$id" 2>/dev/null)"; then
    limits="$(gain_limits "$output")"
    line="$(gain_line "$output")"
    raw="$(gain_raw "$line")"
    percent="$(gain_driver_percent "$line")"
    max="$(gain_max "$limits")"
    type="$(gain_field "$id" type)"
    if [ "$type" = "nzxt-usb-mic" ] && [ -n "$max" ]; then
      mode="$(gain_nzxt_mode "$id" "$max")"
      auto_target="$(gain_nzxt_target_for_mode "$id" "$mode")"
      printf '  detected mode: %s\n' "$mode"
      printf '  auto target now: %s\n' "$auto_target"
    fi
    printf '  range: %s\n' "${limits:-unknown}"
    printf '  current: %s%% (raw %s)\n' "${percent:-?}" "${raw:-?}"
  else
    printf '  current: missing\n'
  fi
}

gain_status() {
  service="$(jq -r '.service' "$gains_config")"
  echo "service: $service, runtime=$(service_state "$service")"
  ids="$(gain_ids)"
  if [ -z "$ids" ]; then
    echo
    echo "none"
    return
  fi

  printf '%s\n' "$ids" | while read -r id; do
    echo
    gain_item_status "$id"
  done
}

combined_outputs_status() {
  outputs="$(
    jq -r '.combinedOutputs | to_entries[] | [
      .key,
      (.value.enable | tostring),
      .value.description,
      .value.nodeName,
      (.value.outputs | join(", "))
    ] | @tsv' "$routing_config"
  )"

  if [ -z "$outputs" ]; then
    echo "none"
    return
  fi

  first=true
  printf '%s\n' "$outputs" | while IFS=$'\t' read -r id enabled description node_name output_names; do
    if [ "$first" = "true" ]; then
      first=false
    else
      echo
    fi
    node_id="$(node_id_by_name "$node_name" || true)"
    if [ -n "$node_id" ]; then
      runtime="present"
    else
      runtime="missing"
    fi
    printf '%s: config=%s, runtime=%s\n' "$id" "$enabled" "$runtime"
    printf '  label: %s\n' "$(display_label "$description")"
    printf '  outputs: %s\n' "$output_names"
  done
}

gain_set() {
  id="$1"
  value="$2"
  gain_exists "$id" || die "unknown gain: $id"
  if [ "$value" = "auto" ]; then
    type="$(gain_field "$id" type)"
    [ "$type" = "nzxt-usb-mic" ] || die "auto is only supported for nzxt-usb-mic gain targets"
  else
    valid_percent "$value" || die "gain percent must be 0-100: $value"
    value="${value%\%}"
  fi

  mkdir -p "$gains_override_dir"
  printf '%s\n' "$value" > "$(gain_override_file "$id")"
  enable_item "$gains_disabled_file" "$id"
  gain_apply "$id"
  gain_item_status "$id"
}

gain_enable() {
  id="$1"
  gain_exists "$id" || die "unknown gain: $id"
  enable_item "$gains_disabled_file" "$id"
  rm -f "$(gain_override_file "$id")"
  gain_apply "$id"
  gain_item_status "$id"
}

gain_disable() {
  id="$1"
  gain_exists "$id" || die "unknown gain: $id"
  disable_item "$gains_disabled_file" "$id"
  gain_item_status "$id"
}

gains_watch() {
  delay="$(jq -r '.intervalSeconds' "$gains_config")"
  while true; do
    gains_apply_all
    pactl subscribe 2>/dev/null | while read -r event; do
      case "$event" in
        *" on source "*|*" on sink "*|*" on card "*|*" on server "*)
          gains_apply_all
          sleep "$delay"
          ;;
      esac
    done || true
    sleep "$delay"
  done
}

kill_chromium_audio_services() {
  matches="$(pgrep -u "$(id -u)" -af -- '--utility-sub-type=audio.mojom.AudioService' || true)"
  if [ -z "$matches" ]; then
    echo "chromium-audio: none"
    return
  fi

  while IFS= read -r match; do
    pid="${match%% *}"
    command="${match#* }"
    if kill -TERM "$pid" 2>/dev/null; then
      echo "chromium-audio: terminated pid=$pid command=$command"
    else
      echo "chromium-audio: failed pid=$pid command=$command" >&2
    fi
  done <<< "$matches"
}

wait_for_audio_graph() {
  attempts=0
  while [ "$attempts" -lt 30 ]; do
    if wpctl status >/dev/null 2>&1; then
      return
    fi
    attempts=$((attempts + 1))
    sleep 0.25
  done
  echo "warning: PipeWire graph did not become ready within timeout" >&2
}

audio_status() {
  echo "defaults:"
  printf '  input: %s\n' "$(target_label @DEFAULT_AUDIO_SOURCE@)"
  printf '  output: %s\n' "$(target_label @DEFAULT_AUDIO_SINK@)"
  echo

  echo "combined outputs:"
  combined_outputs_status | indent
  echo

  echo "loopbacks:"
  loopback_list | indent
  echo

  echo "locks:"
  locks_status | indent
  echo

  echo "gains:"
  gain_status | indent
}

audio_restart() {
  active_loopbacks="$(loopback_active_ids || true)"

  echo "restart: pipewire pipewire-pulse wireplumber"
  systemctl --user restart pipewire.service pipewire-pulse.service wireplumber.service
  wait_for_audio_graph

  locks_service="$(jq -r '.service' "$locks_config")"
  if unit_exists "$locks_service"; then
    echo "restart: $locks_service"
    systemctl --user restart "$locks_service"
  fi

  gains_service="$(jq -r '.service' "$gains_config")"
  if unit_exists "$gains_service"; then
    echo "restart: $gains_service"
    systemctl --user restart "$gains_service"
  fi

  if [ -n "$active_loopbacks" ]; then
    printf '%s\n' "$active_loopbacks" | while read -r id; do
      service="$(loopback_service "$id")"
      echo "restart: loopback $id ($service)"
      systemctl --user start "$service"
    done
  fi

  kill_chromium_audio_services
  audio_status
}

case "${1:-}" in
  ""|help|--help|-h)
    main_help
    ;;
  status)
    if has_help_arg "${@:2}"; then
      status_help
      exit 0
    fi
    if [ -n "${2:-}" ]; then
      status_help
      exit 2
    fi
    audio_status
    ;;
  list)
    audio_list "${2:-}" "${3:-}"
    ;;
  restart)
    if has_help_arg "${@:2}"; then
      restart_help
      exit 0
    fi
    if [ -n "${2:-}" ]; then
      restart_help
      exit 2
    fi
    audio_restart
    ;;
  loopback)
    case "${2:-}" in
      ""|help|--help|-h)
        loopback_help
        ;;
      status)
        if has_help_arg "${@:3}"; then
          loopback_help
          exit 0
        fi
        loopback_status
        ;;
      list)
        if has_help_arg "${@:3}"; then
          loopback_help
          exit 0
        fi
        loopback_list
        ;;
      rebind)
        if has_help_arg "${@:3}"; then
          loopback_rebind_help
          exit 0
        fi
        loopback_rebind
        ;;
      toggle|on|off)
        if has_help_arg "${@:3}"; then
          loopback_state_help
          exit 0
        fi
        [ -n "${3:-}" ] || die "missing loopback id or name"
        loopback_set_state "$2" "$3"
        ;;
      *)
        loopback_help
        exit 2
        ;;
    esac
    ;;
  locks)
    case "${2:-}" in
      ""|help|--help|-h)
        locks_help
        ;;
      status|list)
        if has_help_arg "${@:3}"; then
          locks_help
          exit 0
        fi
        locks_status
        ;;
      lock)
        if has_help_arg "${@:3}"; then
          locks_lock_help
          exit 0
        fi
        [ -n "${3:-}" ] || die "missing lock id"
        lock_exists "$3" || die "unknown lock: $3"
        enable_item "$locks_disabled_file" "$3"
        lock_apply "$3"
        lock_item_status "$3"
        ;;
      unlock)
        if has_help_arg "${@:3}"; then
          locks_lock_help
          exit 0
        fi
        [ -n "${3:-}" ] || die "missing lock id"
        lock_exists "$3" || die "unknown lock: $3"
        disable_item "$locks_disabled_file" "$3"
        lock_item_status "$3"
        ;;
      watch)
        if has_help_arg "${@:3}"; then
          locks_help
          exit 0
        fi
        locks_watch
        ;;
      *)
        locks_help
        exit 2
        ;;
    esac
    ;;
  gain)
    case "${2:-}" in
      ""|help|--help|-h)
        gain_help
        ;;
      status)
        if has_help_arg "${@:3}"; then
          gain_help
          exit 0
        fi
        gain_status
        ;;
      set)
        if has_help_arg "${@:3}"; then
          gain_set_help
          exit 0
        fi
        [ -n "${3:-}" ] || die "missing gain id"
        [ -n "${4:-}" ] || die "missing gain value"
        gain_set "$3" "$4"
        ;;
      enable)
        if has_help_arg "${@:3}"; then
          gain_state_help
          exit 0
        fi
        [ -n "${3:-}" ] || die "missing gain id"
        gain_enable "$3"
        ;;
      disable)
        if has_help_arg "${@:3}"; then
          gain_state_help
          exit 0
        fi
        [ -n "${3:-}" ] || die "missing gain id"
        gain_disable "$3"
        ;;
      watch)
        if has_help_arg "${@:3}"; then
          gain_help
          exit 0
        fi
        gains_watch
        ;;
      apply-all)
        if has_help_arg "${@:3}"; then
          gain_help
          exit 0
        fi
        gains_apply_all
        ;;
      *)
        gain_help
        exit 2
        ;;
    esac
    ;;
  *)
    main_help
    exit 2
    ;;
esac
