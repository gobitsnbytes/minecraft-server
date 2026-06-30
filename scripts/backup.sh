#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
require_command tar
require_command zstd
require_command systemctl
require_command python3

SERVER_ROOT="${SERVER_ROOT:-/home/minecraft/server}"
SERVER_ENV="${SERVER_ENV:-${SERVER_ROOT}/configs/server.env}"
BACKUP_DIR="${BACKUP_DIR:-${SERVER_ROOT}/backups}"
RETENTION_DAILY="${RETENTION_DAILY:-7}"
BACKUP_RESTART_AFTER="${BACKUP_RESTART_AFTER:-1}"

[[ -f "${SERVER_ENV}" ]] || die "Missing server environment file: ${SERVER_ENV}"
# shellcheck disable=SC1090
source "${SERVER_ENV}"

RCON="${SCRIPT_DIR}/lib/rcon.py"

ensure_dir "${BACKUP_DIR}" 0750

backup_name="bnb-backup-$(timestamp).tar.zst"
backup_path="${BACKUP_DIR}/${backup_name}"

log INFO "Flushing server data before backup"
was_running=false
if systemctl is-active --quiet bnb-minecraft.service; then
  was_running=true
  python3 "${RCON}" --host "${RCON_HOST}" --port "${RCON_PORT}" --password "${RCON_PASSWORD}" --command "save-off"
  python3 "${RCON}" --host "${RCON_HOST}" --port "${RCON_PORT}" --password "${RCON_PASSWORD}" --command "save-all flush"
fi

log INFO "Stopping service for a consistent archive"
systemctl stop bnb-minecraft.service || true

log INFO "Creating compressed backup ${backup_path}"
tar --zstd -cpf "${backup_path}" \
  -C "${SERVER_ROOT}" \
  --exclude='./cache' \
  --exclude='./temp' \
  --exclude='./logs' \
  .

if [[ "${was_running}" == true && "${BACKUP_RESTART_AFTER}" == "1" ]]; then
  log INFO "Restarting service"
  systemctl start bnb-minecraft.service
  log INFO "Re-enabling live saving"
  python3 "${RCON}" --host "${RCON_HOST}" --port "${RCON_PORT}" --password "${RCON_PASSWORD}" --command "save-on" || true
fi

log INFO "Pruning old backups"
find "${BACKUP_DIR}" -maxdepth 1 -type f -name 'bnb-backup-*.tar.zst' | sort | awk "NR > ${RETENTION_DAILY}" | xargs -r rm -f

log INFO "Backup complete: ${backup_path}"
