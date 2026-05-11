#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <gimp-version>"
  echo "example: $0 3.2.6"
  exit 2
fi

version="$1"
major_minor="${version%.*}"
file="GIMP-${version}-x86_64.AppImage"
sums_url="https://download.gimp.org/gimp/v${major_minor}/linux/SHA256SUMS"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
package_file="${script_dir}/default.nix"

hex_hash="$(
  curl -fsSL "$sums_url" |
    awk -v file="$file" '$2 == file { print $1 }'
)"

if [ -z "$hex_hash" ]; then
  echo "could not find ${file} in ${sums_url}" >&2
  exit 1
fi

sri_hash="$(nix hash convert --hash-algo sha256 --to sri "$hex_hash")"
tmp="$(mktemp)"

sed -E \
  -e "s/version = \"[^\"]+\";/version = \"${version}\";/" \
  -e "s#hash = \"sha256-[^\"]+\";#hash = \"${sri_hash}\";#" \
  "$package_file" > "$tmp"

mv "$tmp" "$package_file"

echo "updated ${package_file}"
echo "version: ${version}"
echo "hash: ${sri_hash}"
