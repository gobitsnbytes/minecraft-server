#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
require_command curl
require_command jq

SERVER_ROOT="${SERVER_ROOT:-/home/minecraft/server}"
SERVER_PLUGINS="${SERVER_PLUGINS:-${SERVER_ROOT}/plugins}"
PLUGIN_MANIFEST="${PLUGIN_MANIFEST:-${SERVER_ROOT}/configs/plugins.manifest}"

ensure_dir "${SERVER_PLUGINS}" 0750

download_spigot() {
  local resource_id="$1"
  local target="$2"
  local url="https://api.spiget.org/v2/resources/${resource_id}/download"
  log INFO "Downloading Spigot resource ${resource_id} -> ${target}"
  download_file "${url}" "${target}"
}

download_github_latest() {
  local repo="$1"
  local asset_pattern="$2"
  local target="$3"
  local api="https://api.github.com/repos/${repo}/releases/latest"
  local tmp
  tmp="$(mktemp)"
  curl -fsSL "${api}" -o "${tmp}"
  local asset_url
  asset_url="$(jq -r --arg re "${asset_pattern}" '.assets[] | select(.name | test($re)) | .browser_download_url' "${tmp}" | head -n 1)"
  [[ -n "${asset_url}" && "${asset_url}" != "null" ]] || die "No matching asset for ${repo} with pattern ${asset_pattern}"
  download_file "${asset_url}" "${target}"
  rm -f "${tmp}"
}

[[ -f "${PLUGIN_MANIFEST}" ]] || die "Plugin manifest not found: ${PLUGIN_MANIFEST}"

while IFS='|' read -r name source identifier target; do
  [[ -n "${name}" ]] || continue
  [[ "${name}" =~ ^# ]] && continue
  case "${source}" in
    spiget)
      download_spigot "${identifier}" "${SERVER_PLUGINS}/${target}"
      ;;
    github)
      case "${name}" in
        Geyser)
          download_github_latest "${identifier}" '.*spigot.*\.jar$|.*paper.*\.jar$' "${SERVER_PLUGINS}/${target}"
          ;;
        Floodgate)
          download_github_latest "${identifier}" '.*bukkit.*\.jar$|.*spigot.*\.jar$' "${SERVER_PLUGINS}/${target}"
          ;;
        *)
          die "Unsupported GitHub plugin entry: ${name}"
          ;;
      esac
      ;;
    *)
      die "Unsupported plugin source: ${source}"
      ;;
  esac
done < "${PLUGIN_MANIFEST}"

chown -R minecraft:minecraft "${SERVER_PLUGINS}"
log INFO "Plugin installation complete"
