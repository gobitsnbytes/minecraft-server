#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  local level="$1"
  shift
  printf '%s [%s] %s\n' "$(date -Is)" "$level" "$*" >&2
}

die() {
  log "ERROR" "$*"
  exit 1
}

on_error() {
  local exit_code=$?
  local line=${1:-unknown}
  log "ERROR" "Failed at line ${line} with exit code ${exit_code}"
  exit "${exit_code}"
}

trap 'on_error $LINENO' ERR

require_root() {
  [[ "${EUID}" -eq 0 ]] || die "This script must be run as root."
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

ensure_dir() {
  local path="$1"
  local mode="${2:-0750}"
  install -d -m "$mode" "$path"
}

write_file() {
  local path="$1"
  shift
  local mode="${1:-0644}"
  shift || true
  local tmp
  tmp="$(mktemp)"
  cat >"$tmp"
  install -m "$mode" "$tmp" "$path"
  rm -f "$tmp"
}

service_is_active() {
  systemctl is-active --quiet "$1"
}

restart_service() {
  local svc="$1"
  systemctl restart "$svc"
}

download_file() {
  local url="$1"
  local output="$2"
  curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 10 "$url" -o "$output"
}

timestamp() {
  date -u +"%Y%m%dT%H%M%SZ"
}

