#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
require_command curl
require_command jq
require_command systemctl

SERVER_ROOT="${SERVER_ROOT:-/home/minecraft/server}"
SERVER_RELEASES="${SERVER_RELEASES:-${SERVER_ROOT}/releases}"
SERVER_ENV="${SERVER_ENV:-${SERVER_ROOT}/configs/server.env}"
BACKUP_SCRIPT="${BACKUP_SCRIPT:-${SCRIPT_DIR}/backup.sh}"

[[ -f "${SERVER_ENV}" ]] || die "Missing server environment file: ${SERVER_ENV}"
# shellcheck disable=SC1090
source "${SERVER_ENV}"

log INFO "Creating a rollback backup"
BACKUP_RESTART_AFTER=0 "${BACKUP_SCRIPT}"

log INFO "Stopping service for update"
systemctl stop bnb-minecraft.service

log INFO "Resolving latest Purpur build"
purpur_meta="$(mktemp)"
curl -fsSL "https://api.purpurmc.org/v2/purpur/${PURPUR_MC_VERSION}" -o "${purpur_meta}"
latest_build="$(jq -r '.builds.latest // .latestBuild // .build' "${purpur_meta}")"
rm -f "${purpur_meta}"

release_dir="${SERVER_RELEASES}/purpur-${PURPUR_MC_VERSION}-${latest_build}-$(timestamp)"
ensure_dir "${release_dir}" 0750
download_file "https://api.purpurmc.org/v2/purpur/${PURPUR_MC_VERSION}/${latest_build}/download" "${release_dir}/purpur.jar"
ln -sfn "${release_dir}/purpur.jar" "${SERVER_ROOT}/server.jar"

log INFO "Refreshing plugins"
"${SCRIPT_DIR}/install-plugins.sh"

log INFO "Starting service after update"
systemctl start bnb-minecraft.service
log INFO "Update complete"
