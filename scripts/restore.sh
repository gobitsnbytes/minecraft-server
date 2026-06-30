#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
require_command tar
require_command zstd
require_command systemctl

if [[ $# -ne 1 ]]; then
  die "Usage: $0 /path/to/backup.tar.zst"
fi

BACKUP_FILE="$1"
SERVER_ROOT="${SERVER_ROOT:-/home/minecraft/server}"

[[ -f "${BACKUP_FILE}" ]] || die "Backup file not found: ${BACKUP_FILE}"

log INFO "Stopping service before restore"
systemctl stop bnb-minecraft.service || true

log INFO "Restoring archive ${BACKUP_FILE}"
tar --zstd -xpf "${BACKUP_FILE}" -C "${SERVER_ROOT}"

chown -R minecraft:minecraft "${SERVER_ROOT}"

log INFO "Restore complete. Start the service manually after verification."

