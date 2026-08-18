#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <t3code-version|latest>"
  echo "example: $0 0.0.33"
  exit 2
fi

repo="pingdotgg/t3code"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
version="${1#v}"

if [ -n "${T3CODE_NIX_CONFIG:-}" ]; then
  config_file="$T3CODE_NIX_CONFIG"
else
  config_file="$(CDPATH= cd -- "${script_dir}/../../system" && pwd)/configuration.nix"
fi

current_version="$(
  awk '
    /^[[:space:]]*programs\.t3code = \{/ { in_block = 1 }
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
      jq -r '.tag_name // empty | sub("^v"; "")'
  )"

  if [ -z "$version" ]; then
    echo "could not determine latest T3 Code version" >&2
    exit 1
  fi
fi

if ! [[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  echo "invalid T3 Code version: ${version}" >&2
  exit 2
fi

if [ "$version" = "$current_version" ]; then
  echo "T3 Code is already pinned to ${version}; nothing to update."
  exit 0
fi

url="https://github.com/${repo}/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage"
hash="$(
  nix store prefetch-file --hash-type sha256 --json "$url" |
    jq -r '.hash'
)"

if [ -z "$hash" ] || [ "$hash" = "null" ]; then
  echo "could not prefetch ${url}" >&2
  exit 1
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

if ! awk -v version="$version" -v hash="$hash" '
  /^[[:space:]]*programs\.t3code = \{/ { in_block = 1 }
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
      print "could not update programs.t3code.version in " FILENAME > "/dev/stderr"
      exit 1
    }
    if (!hash_updated) {
      print "could not update programs.t3code.hash in " FILENAME > "/dev/stderr"
      exit 1
    }
  }
' "$config_file" > "$tmp"; then
  exit 1
fi

chmod --reference="$config_file" "$tmp"
mv "$tmp" "$config_file"
trap - EXIT

echo "updated ${config_file}"
echo "version: ${version}"
echo "hash: ${hash}"
