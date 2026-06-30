#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
require_command curl
require_command javac
require_command jar

PLUGIN_DIR="${PROJECT_ROOT}/plugins/consent-plugin"
BUILD_DIR="${PLUGIN_DIR}/build"
CLASSES_DIR="${BUILD_DIR}/classes"
SERVER_JAR="${SERVER_JAR:-/home/minecraft/server/server.jar}"

[[ -d "${PLUGIN_DIR}/src/main/java" ]] || die "Missing plugin source tree: ${PLUGIN_DIR}"
ensure_dir "${CLASSES_DIR}" 0755

[[ -f "${SERVER_JAR}" ]] || die "Missing server jar for compilation: ${SERVER_JAR}"

log INFO "Compiling consent plugin"
find "${CLASSES_DIR}" -mindepth 1 -delete || true

mapfile -t sources < <(find "${PLUGIN_DIR}/src/main/java" -name '*.java' | sort)
[[ "${#sources[@]}" -gt 0 ]] || die "No Java sources found for consent plugin"

javac -encoding UTF-8 --release 21 -cp "${SERVER_JAR}" -d "${CLASSES_DIR}" "${sources[@]}"

if [[ -d "${PLUGIN_DIR}/src/main/resources" ]]; then
  cp -a "${PLUGIN_DIR}/src/main/resources/." "${CLASSES_DIR}/"
fi

jar --create --file "${BUILD_DIR}/bnb-consent.jar" -C "${CLASSES_DIR}" .
log INFO "Built ${BUILD_DIR}/bnb-consent.jar"
