#!/usr/bin/env bash
set -euo pipefail

app_name="Adobe DNG Converter"
converter_url="${ADOBE_DNG_CONVERTER_INSTALLER_URL:-https://www.adobe.com/go/dng_converter_win}"

xdg_data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
xdg_cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
migration_wineprefix="$xdg_data_home/darktable-adobe-dng/wineprefix"
wineprefix="${ADOBE_DNG_CONVERTER_WINEPREFIX:-$xdg_data_home/adobe-dng-converter/wineprefix}"
installer_cache_dir="$xdg_cache_home/adobe-dng-converter"
migration_installer_cache_dir="$xdg_cache_home/darktable-adobe-dng"

usage() {
  cat <<EOF
Usage:
  adobe-dng-converter [--gui-launcher] [--install] [--status] [--path] [--help] [ARG...]

Launch Adobe DNG Converter under Wine. If it is missing, prompt before
downloading and installing it from Adobe.

Environment:
  ADOBE_DNG_CONVERTER_EXE           Override converter executable path.
  ADOBE_DNG_CONVERTER_WINEPREFIX    Wine prefix to use.
  ADOBE_DNG_CONVERTER_INSTALLER_URL Installer URL.
EOF
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
    printf 'Downloading %s from Adobe. This is a large download.\n' "$app_name" >&2
    curl --fail --location --progress-bar --output "$installer.part" "$converter_url"
    mv -f "$installer.part" "$installer"
  else
    printf 'Using cached installer: %s\n' "$installer" >&2
  fi

  printf 'Installing into Wine prefix: %s\n' "$wineprefix" >&2
  WINEPREFIX="$wineprefix" wine64 "$installer"
  WINEPREFIX="$wineprefix" wineserver -w || true

  find_converter >/dev/null || {
    printf 'Install completed, but %s was not found in the Wine prefix.\n' "$app_name" >&2
    return 1
  }
}

ensure_converter() {
  if find_converter >/dev/null; then
    return 0
  fi

  printf '%s is not installed in the configured Wine prefixes.\n\n' "$app_name" >&2
  printf 'Primary prefix: %s\n' "$wineprefix" >&2
  printf 'Installer source: %s\n\n' "$converter_url" >&2

  if prompt_yes_no "Download and install $app_name now?"; then
    install_converter
    return $?
  fi

  printf 'Cancelled. Nothing was installed.\n' >&2
  return 1
}

launch_converter() {
  local converter prefix
  converter="$(find_converter)"
  prefix="$(prefix_for_converter "$converter")"

  printf 'Launching: %s\n' "$converter" >&2
  printf 'Wine prefix: %s\n' "$prefix" >&2

  cd "$(dirname "$converter")"

  WINEPREFIX="$prefix" wine64 "$converter" "$@"
}

launch_konsole_supervisor() {
  local title="Adobe DNG Converter Launcher $$"
  local self

  self="$(readlink -f "$0")"

  if find_converter >/dev/null; then
    nohup "$self" --gui-child "$@" >/dev/null 2>&1 &
    return 0
  fi

  nohup konsole \
    --separate \
    --nofork \
    --hide-menubar \
    --hide-tabbar \
    --qwindowtitle "$title" \
    -p "tabtitle=$title" \
    -p "LocalTabTitleFormat=$title" \
    -e "$self" --gui-child "$@" \
    >/dev/null 2>&1 &
}

main() {
  case "${1:-}" in
    --gui-launcher)
      shift
      launch_konsole_supervisor "$@"
      exit 0
      ;;
    --gui-child)
      shift
      ensure_converter
      launch_converter "$@"
      exit $?
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --install)
      install_converter
      exit 0
      ;;
    --status)
      if converter="$(find_converter)"; then
        printf 'Installed: %s\n' "$converter"
        printf 'Wine prefix: %s\n' "$(prefix_for_converter "$converter")"
      else
        printf 'Not installed\n'
        exit 1
      fi
      exit 0
      ;;
    --path)
      find_converter
      exit $?
      ;;
  esac

  ensure_converter
  launch_converter "$@"
}

main "$@"
