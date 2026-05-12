#!/usr/bin/env bash
set -uo pipefail

converter_url="${ADOBE_DNG_CONVERTER_INSTALLER_URL:-https://www.adobe.com/go/dng_converter_win}"
dng_options="${CONVERT_DNG_OPTIONS:--u -p1 -dng1.6}"
backup_dir_name="${CONVERT_DNG_BACKUP_DIR:-pre-conversion}"
wine_debug="${CONVERT_DNG_WINEDEBUG:--all}"
heartbeat_seconds="${CONVERT_DNG_HEARTBEAT_SECONDS:-5}"

xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
xdg_cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
migration_wineprefix="$xdg_data_home/darktable-adobe-dng/wineprefix"
wineprefix="${ADOBE_DNG_CONVERTER_WINEPREFIX:-$xdg_data_home/adobe-dng-converter/wineprefix}"
installer_cache_dir="$xdg_cache_home/adobe-dng-converter"
migration_installer_cache_dir="$xdg_cache_home/darktable-adobe-dng"

usage() {
  cat <<EOF
Usage:
  convert-dng FILE...

Convert Apple ProRAW DNG files in place using Adobe DNG Converter.
Original files are moved to <photo-folder>/$backup_dir_name/.

Examples:
  convert-dng ./photo.DNG
  convert-dng ./*.DNG

Environment:
  ADOBE_DNG_CONVERTER_EXE        Override converter executable path.
  ADOBE_DNG_CONVERTER_WINEPREFIX Wine prefix to use for new installs.
  CONVERT_DNG_OPTIONS            Adobe options. Default: $dng_options
  CONVERT_DNG_BACKUP_DIR         Backup dir name. Default: $backup_dir_name
  CONVERT_DNG_HEARTBEAT_SECONDS  Progress interval. Default: $heartbeat_seconds
  CONVERT_DNG_WINEDEBUG          Wine debug setting. Default: $wine_debug
EOF
}

log() {
  printf '[%(%H:%M:%S)T] %s\n' -1 "$*" >&2
}

prompt_yes_no() {
  local prompt="$1"
  local reply

  printf '%s [y/N] ' "$prompt" >&2
  if ! read -r reply; then
    printf '\n' >&2
    return 1
  fi

  case "$reply" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

converter_candidates() {
  local prefixes=(
    "$wineprefix"
    "$migration_wineprefix"
    "$HOME/.wine"
  )

  local prefix
  for prefix in "${prefixes[@]}"; do
    printf '%s\n' \
      "$prefix/drive_c/Program Files/Adobe/Adobe DNG Converter/Adobe DNG Converter.exe" \
      "$prefix/drive_c/Program Files/Adobe DNG Converter/Adobe DNG Converter.exe" \
      "$prefix/drive_c/Program Files/Adobe DNG Converter.exe"
  done
}

find_converter() {
  if [ -n "${ADOBE_DNG_CONVERTER_EXE:-}" ]; then
    printf '%s\n' "$ADOBE_DNG_CONVERTER_EXE"
    return 0
  fi

  local candidate
  while IFS= read -r candidate; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(converter_candidates)

  return 1
}

prefix_for_converter() {
  local converter="$1"

  case "$converter" in
    "$wineprefix"/drive_c/*)
      printf '%s\n' "$wineprefix"
      ;;
    "$migration_wineprefix"/drive_c/*)
      printf '%s\n' "$migration_wineprefix"
      ;;
    "$HOME/.wine"/drive_c/*)
      printf '%s\n' "$HOME/.wine"
      ;;
    *)
      printf '%s\n' "$wineprefix"
      ;;
  esac
}

installer_path() {
  local current="$installer_cache_dir/AdobeDNGConverter_x64.exe"
  local migration="$migration_installer_cache_dir/AdobeDNGConverter_x64.exe"

  if [ -s "$current" ]; then
    printf '%s\n' "$current"
  elif [ -s "$migration" ]; then
    printf '%s\n' "$migration"
  else
    printf '%s\n' "$current"
  fi
}

install_converter() {
  mkdir -p "$installer_cache_dir" "$wineprefix"

  local installer
  installer="$(installer_path)"

  if [ ! -s "$installer" ]; then
    log "Downloading Adobe DNG Converter from Adobe. This is a large download."
    curl --fail --location --progress-bar --output "$installer.part" "$converter_url" || return 1
    mv -f "$installer.part" "$installer" || return 1
  else
    log "Using cached installer: $installer"
  fi

  log "Installing into Wine prefix: $wineprefix"
  WINEPREFIX="$wineprefix" wine64 "$installer" || return 1
  WINEPREFIX="$wineprefix" wineserver -w || true

  find_converter >/dev/null
}

ensure_converter() {
  if find_converter >/dev/null; then
    return 0
  fi

  log "Adobe DNG Converter is not installed in the configured Wine prefixes."
  log "Primary prefix: $wineprefix"
  log "Installer source: $converter_url"

  if prompt_yes_no "Download and install Adobe DNG Converter now?"; then
    install_converter
    return $?
  fi

  log "Cancelled. Nothing was installed."
  return 1
}

json_field() {
  local json="$1"
  local key="$2"

  printf '%s' "$json" | jq -r --arg key "$key" '.[0][$key] // ""'
}

metadata_json() {
  exiftool -json -a -G1 -s \
    -IFD0:Make \
    -IFD0:Model \
    -IFD0:Software \
    -IFD0:DNGVersion \
    -IFD0:UniqueCameraModel \
    -SubIFD:Compression \
    -SubIFD:PhotometricInterpretation \
    -- \
    "$1"
}

is_apple_proraw_needing_conversion() {
  local file="$1"
  local json make model unique software dng_version compression photometric

  case "${file##*.}" in
    DNG|dng)
      ;;
    *)
      return 1
      ;;
  esac

  json="$(metadata_json "$file")" || return 1
  make="$(json_field "$json" "IFD0:Make")"
  model="$(json_field "$json" "IFD0:Model")"
  unique="$(json_field "$json" "IFD0:UniqueCameraModel")"
  software="$(json_field "$json" "IFD0:Software")"
  dng_version="$(json_field "$json" "IFD0:DNGVersion")"
  compression="$(json_field "$json" "SubIFD:Compression")"
  photometric="$(json_field "$json" "SubIFD:PhotometricInterpretation")"

  log "Metadata: make='$make' model='$model' unique='$unique' software='$software' compression='$compression' photometric='$photometric'"

  case "$software" in
    *"Adobe DNG Converter"*)
      return 1
      ;;
  esac

  [ "$make" = "Apple" ] || return 1
  [[ "$model $unique" == *iPhone* ]] || return 1
  [ -n "$dng_version" ] || return 1
  [ "$compression" = "JPEG" ] || return 1
  [ "$photometric" = "Linear Raw" ] || return 1
}

unique_backup_path() {
  local backup_dir="$1"
  local base="$2"
  local stem="${base%.*}"
  local ext=""
  local candidate="$backup_dir/$base"

  if [[ "$base" == *.* ]]; then
    ext=".${base##*.}"
  fi

  if [ ! -e "$candidate" ]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  local stamp index
  stamp="$(date +%Y%m%dT%H%M%S)"
  index=1
  while :; do
    candidate="$backup_dir/${stem}-${stamp}-${index}${ext}"
    if [ ! -e "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
    index=$((index + 1))
  done
}

to_windows_path() {
  local prefix="$1"
  local path="$2"

  WINEPREFIX="$prefix" WINEDEBUG="$wine_debug" wine64 winepath -w "$path"
}

run_adobe_converter() {
  local prefix="$1"
  local converter="$2"
  local input="$3"
  local out_dir="$4"
  local out_name="$5"
  local log_file="$6"

  local win_out_dir win_input pid rc start elapsed
  win_out_dir="$(to_windows_path "$prefix" "$out_dir")" || return 1
  win_input="$(to_windows_path "$prefix" "$input")" || return 1

  # shellcheck disable=SC2206
  local options=( $dng_options )

  log "Adobe command: wine64 '$converter' ${options[*]} -d '$win_out_dir' -o '$out_name' '$win_input'"

  (
    WINEPREFIX="$prefix" WINEDEBUG="$wine_debug" wine64 "$converter" \
      "${options[@]}" \
      -d "$win_out_dir" \
      -o "$out_name" \
      "$win_input"
    rc=$?
    WINEPREFIX="$prefix" WINEDEBUG="$wine_debug" wineserver -w || true
    exit "$rc"
  ) >"$log_file" 2>&1 &

  pid=$!
  start=$SECONDS

  while kill -0 "$pid" 2>/dev/null; do
    sleep "$heartbeat_seconds"
    if kill -0 "$pid" 2>/dev/null; then
      elapsed=$((SECONDS - start))
      log "Still converting '$out_name' (${elapsed}s elapsed)"
    fi
  done

  wait "$pid"
  rc=$?

  return "$rc"
}

validate_converted_file() {
  local file="$1"
  local json software compression photometric

  [ -s "$file" ] || return 1

  json="$(metadata_json "$file")" || return 1
  software="$(json_field "$json" "IFD0:Software")"
  compression="$(json_field "$json" "SubIFD:Compression")"
  photometric="$(json_field "$json" "SubIFD:PhotometricInterpretation")"

  log "Converted metadata: software='$software' compression='$compression' photometric='$photometric'"

  case "$software" in
    *"Adobe DNG Converter"*)
      ;;
    *)
      log "Converted file does not report Adobe DNG Converter as Software."
      return 1
      ;;
  esac

  [ "$photometric" = "Linear Raw" ] || return 1
}

convert_one() {
  local input="$1"
  local converter="$2"
  local prefix="$3"

  local file dir base backup_dir backup_path tmp out_dir converted log_file rc

  if [ ! -f "$input" ]; then
    log "ERROR: file not found: $input"
    return 1
  fi

  file="$(readlink -f "$input")" || return 1
  dir="$(dirname "$file")"
  base="$(basename "$file")"
  backup_dir="$dir/$backup_dir_name"

  log "Checking: $file"

  if ! is_apple_proraw_needing_conversion "$file"; then
    log "SKIP: not an unconverted Apple ProRAW DNG matching this workaround."
    return 2
  fi

  tmp="$(mktemp -d "${TMPDIR:-/tmp}/convert-dng.XXXXXX")" || return 1
  out_dir="$tmp/out"
  log_file="$tmp/adobe-dng-converter.log"
  mkdir -p "$out_dir" || {
    rm -rf "$tmp"
    return 1
  }

  log "Converting to temporary directory: $out_dir"
  run_adobe_converter "$prefix" "$converter" "$file" "$out_dir" "$base" "$log_file"
  rc=$?

  if [ "$rc" -ne 0 ]; then
    log "ERROR: Adobe DNG Converter exited with code $rc"
    if [ -s "$log_file" ]; then
      log "Adobe output follows:"
      sed 's/^/  | /' "$log_file" >&2
    fi
    rm -rf "$tmp"
    return 1
  fi

  converted="$out_dir/$base"
  if ! validate_converted_file "$converted"; then
    log "ERROR: converted file failed validation: $converted"
    if [ -s "$log_file" ]; then
      log "Adobe output follows:"
      sed 's/^/  | /' "$log_file" >&2
    fi
    rm -rf "$tmp"
    return 1
  fi

  mkdir -p "$backup_dir" || {
    rm -rf "$tmp"
    return 1
  }

  backup_path="$(unique_backup_path "$backup_dir" "$base")" || {
    rm -rf "$tmp"
    return 1
  }

  log "Moving original to: $backup_path"
  mv -- "$file" "$backup_path" || {
    rm -rf "$tmp"
    return 1
  }

  log "Writing converted DNG to: $file"
  if ! mv -- "$converted" "$file"; then
    log "ERROR: failed to move converted file into place; restoring original."
    mv -- "$backup_path" "$file" || true
    rm -rf "$tmp"
    return 1
  fi

  rm -rf "$tmp"
  log "OK: converted '$file'"
  return 0
}

main() {
  case "${1:-}" in
    --help|-h|"")
      usage
      if [ "${1:-}" = "" ]; then
        exit 2
      fi
      exit 0
      ;;
  esac

  ensure_converter || exit 1

  local converter prefix total converted skipped failed rc input
  converter="$(find_converter)" || exit 1
  prefix="$(prefix_for_converter "$converter")"
  total=$#
  converted=0
  skipped=0
  failed=0

  log "Using Adobe DNG Converter: $converter"
  log "Using Wine prefix: $prefix"
  log "Backup directory name: $backup_dir_name"
  log "Files requested: $total"

  for input in "$@"; do
    if convert_one "$input" "$converter" "$prefix"; then
      rc=0
    else
      rc=$?
    fi

    case "$rc" in
      0)
        converted=$((converted + 1))
        ;;
      2)
        skipped=$((skipped + 1))
        ;;
      *)
        failed=$((failed + 1))
        ;;
    esac
  done

  log "Summary: converted=$converted skipped=$skipped failed=$failed total=$total"
  log "Scope note: this script is intentionally for Apple ProRAW DNGs that darktable cannot read. For non-Apple RAW photos it is usually not useful; use darktable directly or Adobe DNG Converter's normal GUI/general workflow."

  if [ "$failed" -gt 0 ]; then
    exit 1
  fi

  exit 0
}

main "$@"
