#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: update-t3code [latest|VERSION]

Update the pinned T3 Code AppImage version and hash. Defaults to latest stable.
Run bnix afterwards to install the update.

Set T3CODE_NIX_SOURCE to update a different source.json file.
EOF
}

if [[ $# -eq 1 && ( $1 == --help || $1 == -h ) ]]; then
  usage
  exit 0
fi
if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

version="${1:-latest}"
version="${version#v}"
if [[ $version != latest && ! $version =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  echo "Invalid T3 Code version: $version" >&2
  exit 2
fi

if [[ -n ${T3CODE_NIX_SOURCE:-} ]]; then
  source_file="$T3CODE_NIX_SOURCE"
else
  script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
  source_file="$script_dir/source.json"
fi

current_version="$(jq -er '.version | select(type == "string" and length > 0)' "$source_file")"
if [[ $version == latest ]]; then
  version="$(
    curl --fail --silent --show-error --location --connect-timeout 5 --max-time 30 \
      https://api.github.com/repos/pingdotgg/t3code/releases/latest |
      jq -er '.tag_name | select(type == "string") | sub("^v"; "")'
  )"
fi
if [[ ! $version =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  echo "Invalid T3 Code release version: $version" >&2
  exit 1
fi
if [[ $version == "$current_version" ]]; then
  echo "T3 Code is already pinned to $version; nothing to update."
  exit 0
fi

url="https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage"
hash="$(nix store prefetch-file --hash-type sha256 --json "$url" | jq -er '.hash')"
if [[ ! $hash =~ ^sha256-[A-Za-z0-9+/]{43}=$ ]]; then
  echo "Invalid SHA256 hash returned for $url" >&2
  exit 1
fi

# Stage beside the pin so rename is atomic, even when /tmp is another filesystem.
tmp="$(mktemp "${source_file}.XXXXXX")"
trap 'rm -f -- "$tmp"' EXIT
jq --arg version "$version" --arg hash "$hash" \
  '.version = $version | .hash = $hash' "$source_file" > "$tmp"
chmod --reference="$source_file" "$tmp"
mv -- "$tmp" "$source_file"
trap - EXIT

printf 'Updated %s\nVersion: %s\nHash: %s\nRun bnix to install the update.\n' "$source_file" "$version" "$hash"
