#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

SERVER_ROOT="${SERVER_ROOT:-/home/minecraft/server}"
SERVER_ENV="${SERVER_ENV:-${SERVER_ROOT}/configs/server.env}"

if [[ -f "${SERVER_ENV}" ]]; then
  # shellcheck disable=SC1090
  source "${SERVER_ENV}"
fi

echo "== service =="
systemctl is-active bnb-minecraft.service
echo

echo "== memory =="
free -h
echo

echo "== cpu =="
uptime
echo

echo "== disk =="
df -h "${SERVER_ROOT}"
echo

echo "== network =="
ip -s link
echo

echo "== recent log lines =="
journalctl -u bnb-minecraft.service -n 50 --no-pager

java_pid="$(pgrep -f 'purpur\.jar' | head -n 1 || true)"
if [[ -n "${java_pid}" ]]; then
  echo
  echo "== jvm heap =="
  jcmd "${java_pid}" GC.heap_info || true
  echo
  echo "== jvm gc =="
  jstat -gcutil "${java_pid}" 1 1 || true
fi

if [[ -n "${RCON_PASSWORD:-}" && -x "${SCRIPT_DIR}/lib/rcon.py" ]] && systemctl is-active --quiet bnb-minecraft.service; then
  echo
  echo "== spark tps =="
  python3 "${SCRIPT_DIR}/lib/rcon.py" --host "${RCON_HOST}" --port "${RCON_PORT}" --password "${RCON_PASSWORD}" --command "spark tps" || true
  echo
  echo "== spark gc =="
  python3 "${SCRIPT_DIR}/lib/rcon.py" --host "${RCON_HOST}" --port "${RCON_PORT}" --password "${RCON_PASSWORD}" --command "spark gc" || true
fi
