#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <postman-version|latest>"
  echo "example: $0 12.22.8"
  exit 2
fi

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
version="$1"

if [ -n "${POSTMAN_NIX_CONFIG:-}" ]; then
  config_file="$POSTMAN_NIX_CONFIG"
else
  config_file="$(CDPATH= cd -- "${script_dir}/../../system" && pwd)/configuration.nix"
fi

current_version="$(
  awk '
    /^[[:space:]]*programs\.postman = \{/ { in_block = 1 }
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
    curl -fsSL \
      --get \
      --data-urlencode "currentVersion=${current_version}" \
      --data-urlencode "platform=linux_64" \
      https://dl.pstmn.io/update/status |
      jq -r '.version // empty'
  )"

  if [ -z "$version" ]; then
    echo "Postman is already pinned to the latest version (${current_version}); nothing to update."
    exit 0
  fi
fi

if ! [[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  echo "invalid Postman version: ${version}" >&2
  exit 2
fi

if [ "$version" = "$current_version" ]; then
  echo "Postman is already pinned to ${version}; nothing to update."
  exit 0
fi

url="https://dl.pstmn.io/download/version/${version}/linux64"
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
  /^[[:space:]]*programs\.postman = \{/ { in_block = 1 }
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
      print "could not update programs.postman.version in " FILENAME > "/dev/stderr"
      exit 1
    }
    if (!hash_updated) {
      print "could not update programs.postman.hash in " FILENAME > "/dev/stderr"
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
