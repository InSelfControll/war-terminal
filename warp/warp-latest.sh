#!/usr/bin/env nix-shell
#!nix-shell -i bash -p cacert curl jq nix moreutils coreutils --pure
#shellcheck shell=bash
set -euo pipefail

cd "$(dirname "$0")"

err() {
  echo "ERROR: $*" >&2
  exit 1
}

json_get() {
  jq -r "$1" < "./versions.json"
}

json_set() {
  jq --arg x "$2" "$1 = \$x" < "./versions.json" | sponge "./versions.json"
}

# Follow Warp's redirect just to discover the latest version
resolve_latest_version() {
  local pkg sfx url
  case "$1" in
    darwin)         pkg=macos;        sfx=dmg         ;;
    linux_x86_64)   pkg=pacman;       sfx=pkg.tar.zst ;;
    linux_aarch64)  pkg=pacman_arm64; sfx=pkg.tar.zst ;;
    *) err "Unexpected system: $1" ;;
  esac

  url="https://app.warp.dev/download?package=${pkg}"

  for _ in $(seq 1 15); do
    url="$(curl -s -o /dev/null -w '%{redirect_url}' "$url")"
    [[ "$url" == *."$sfx" ]] && break
  done

  [[ "$url" == *."$sfx" ]] || err "Failed to resolve final URL for $1"
  echo "$url" | grep -oP -m1 '(?<=/v)[\d.\w]+(?=/)'
}

# Construct the EXACT URL used by package.nix for fetchurl
final_release_url_for() {
  local sys="$1"
  local version="$2"
  case "$sys" in
    darwin)
      echo "https://releases.warp.dev/stable/v${version}/Warp.dmg"
      ;;
    linux_x86_64)
      echo "https://releases.warp.dev/stable/v${version}/warp-terminal-v${version}-1-x86_64.pkg.tar.zst"
      ;;
    linux_aarch64)
      echo "https://releases.warp.dev/stable/v${version}/warp-terminal-v${version}-1-aarch64.pkg.tar.zst"
      ;;
    *)
      err "Unexpected system for final URL: $sys"
      ;;
  esac
}

# Compute SRI hash the same way Nix will for fetchurl
compute_sri() {
  local url="$1"
  local sri=""
  
  if command -v nix >/dev/null 2>&1; then
    if nix store prefetch-file --help 2>&1 | grep -q -- '--hash-type'; then
      sri="$(nix store prefetch-file --hash-type sha256 --json "$url" | jq -r '.hash')"
    fi
  fi

  if [[ -z "$sri" ]]; then
    if command -v nix-prefetch-url >/dev/null 2>&1; then
      local raw
      raw="$(nix-prefetch-url --type sha256 "$url")"
      sri="$(nix hash to-sri --type sha256 "$raw")"
    else
      err "Neither 'nix store prefetch-file' nor 'nix-prefetch-url' is available"
    fi
  fi

  [[ -n "$sri" ]] || err "Failed to compute SRI for $url"
  echo "$sri"
}

echo "[*] Checking Warp versions and verifying hashes..."

updates=false

for sys in darwin linux_x86_64 linux_aarch64; do
  echo "==> $sys"
  
  # Always get the latest version
  latest_version="$(resolve_latest_version "$sys")" || err "Could not resolve latest version for $sys"
  current_version="$(json_get ".${sys}.version")"
  current_hash="$(json_get ".${sys}.hash")"
  
  echo "  - Latest version: $latest_version"
  echo "  - Current version: $current_version"
  
  # Always compute the correct hash for the current version in versions.json
  # This ensures we catch incorrect hashes even if version hasn't changed
  final_url="$(final_release_url_for "$sys" "$current_version")"
  echo "  - Verifying hash for current version..."
  correct_hash="$(compute_sri "$final_url")"
  
  version_changed=false
  hash_incorrect=false
  
  # Check if version changed
  if [[ "$latest_version" != "$current_version" ]]; then
    echo "  - Version update needed: $current_version -> $latest_version"
    version_changed=true
  fi
  
  # Check if current hash is incorrect
  if [[ "$current_hash" != "$correct_hash" ]]; then
    echo "  - Hash correction needed:"
    echo "    Current:  $current_hash"
    echo "    Correct:  $correct_hash"
    hash_incorrect=true
  fi
  
  # Update if version changed OR hash is incorrect
  if [[ "$version_changed" == true || "$hash_incorrect" == true ]]; then
    if [[ "$version_changed" == true ]]; then
      # Need to compute hash for the NEW version
      final_url="$(final_release_url_for "$sys" "$latest_version")"
      echo "  - Computing hash for new version..."
      correct_hash="$(compute_sri "$final_url")"
      json_set ".${sys}.version" "$latest_version"
    fi
    
    json_set ".${sys}.hash" "$correct_hash"
    echo "  - Updated: version=$latest_version, hash=$correct_hash"
    updates=true
  else
    echo "  - Up to date and hash verified"
  fi
done

if [[ "$updates" == true ]]; then
  echo "[*] Applying Home Manager config..."
  home-manager switch
  echo "[✔] Warp updated successfully with verified hashes"
else
  echo "[✔] All versions and hashes are correct"
fi
