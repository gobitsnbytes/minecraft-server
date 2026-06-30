#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
require_command python3
require_command systemctl

SERVER_ROOT="${SERVER_ROOT:-/home/minecraft/server}"
SERVER_ENV="${SERVER_ENV:-${SERVER_ROOT}/configs/server.env}"

[[ -f "${SERVER_ENV}" ]] || die "Missing server environment file: ${SERVER_ENV}"
# shellcheck disable=SC1090
source "${SERVER_ENV}"

RCON="${SCRIPT_DIR}/lib/rcon.py"
[[ -x "${RCON}" ]] || chmod +x "${RCON}"

log INFO "Requesting world save before pregeneration"
python3 "${RCON}" --host "${RCON_HOST}" --port "${RCON_PORT}" --password "${RCON_PASSWORD}" --command "save-all flush"
python3 "${RCON}" --host "${RCON_HOST}" --port "${RCON_PORT}" --password "${RCON_PASSWORD}" --command "chunky world world"
python3 "${RCON}" --host "${RCON_HOST}" --port "${RCON_PORT}" --password "${RCON_PASSWORD}" --command "chunky shape circle"
python3 "${RCON}" --host "${RCON_HOST}" --port "${RCON_PORT}" --password "${RCON_PASSWORD}" --command "chunky radius 3000"
python3 "${RCON}" --host "${RCON_HOST}" --port "${RCON_PORT}" --password "${RCON_PASSWORD}" --command "chunky quiet 300"
python3 "${RCON}" --host "${RCON_HOST}" --port "${RCON_PORT}" --password "${RCON_PASSWORD}" --command "chunky start"
log INFO "Chunky pregeneration has been started. Monitor the console until it completes."
