#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <helium-version|latest>"
  echo "example: $0 0.12.4.1"
  exit 2
fi

repo="imputnet/helium-linux"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
version="$1"

if [ -n "${HELIUM_NIX_CONFIG:-}" ]; then
  config_file="$HELIUM_NIX_CONFIG"
else
  config_file="$(CDPATH= cd -- "${script_dir}/../../system" && pwd)/configuration.nix"
fi

current_version="$(
  awk '
    /^[[:space:]]*programs\.helium = \{/ { in_block = 1 }
    in_block && /^[[:space:]]*version = "/ {
      sub(/^[[:space:]]*version = "/, "")
      sub(/";[[:space:]]*$/, "")
      print
      found = 1
      exit
    }
    in_block && /^[[:space:]]*\};/ { in_block = 0 }
    END { if (!found) exit 1 }
  ' "$config_file"
)"

if [ "$version" = "latest" ]; then
  version="$(
    curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" |
      jq -r '.tag_name // empty'
  )"

  if [ -z "$version" ]; then
    echo "could not determine latest Helium version" >&2
    exit 1
  fi
fi

if [ "$version" = "$current_version" ]; then
  echo "Helium is already pinned to ${version}; nothing to update."
  exit 0
fi

url="https://github.com/${repo}/releases/download/${version}/helium-${version}-x86_64.AppImage"
hash="$(
  nix store prefetch-file --hash-type sha256 --json "$url" |
    jq -r '.hash'
)"

if [ -z "$hash" ] || [ "$hash" = "null" ]; then
  echo "could not prefetch ${url}" >&2
  exit 1
fi

tmp="$(mktemp)"
if ! awk -v version="$version" -v hash="$hash" '
  /^[[:space:]]*programs\.helium = \{/ { in_block = 1 }
  in_block && /^[[:space:]]*version = "/ {
    sub(/version = "[^"]+";/, "version = \"" version "\";")
    version_updated = 1
  }
  in_block && /^[[:space:]]*hash = "/ {
    sub(/hash = "sha256-[^"]+";/, "hash = \"" hash "\";")
    hash_updated = 1
  }
  in_block && /^[[:space:]]*\};/ { in_block = 0 }
  { print }
  END {
    if (!version_updated) {
      print "could not update programs.helium.version in " FILENAME > "/dev/stderr"
      exit 1
    }
    if (!hash_updated) {
      print "could not update programs.helium.hash in " FILENAME > "/dev/stderr"
      exit 1
    }
  }
' "$config_file" > "$tmp"; then
  rm -f "$tmp"
  exit 1
fi

mv "$tmp" "$config_file"

echo "updated ${config_file}"
echo "version: ${version}"
echo "hash: ${hash}"
