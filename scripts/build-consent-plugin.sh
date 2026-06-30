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
LIB_DIR="${BUILD_DIR}/lib"
API_VERSION="${API_VERSION:-26.1.2-R0.1-SNAPSHOT}"
API_JAR="${LIB_DIR}/paper-api-${API_VERSION}.jar"
API_URL="${API_URL:-https://repo.papermc.io/repository/maven-public/io/papermc/paper/paper-api/${API_VERSION}/paper-api-${API_VERSION}.jar}"

[[ -d "${PLUGIN_DIR}/src/main/java" ]] || die "Missing plugin source tree: ${PLUGIN_DIR}"
ensure_dir "${CLASSES_DIR}" 0755
ensure_dir "${LIB_DIR}" 0755

if [[ ! -f "${API_JAR}" ]]; then
  log INFO "Downloading Paper API ${API_VERSION}"
  download_file "${API_URL}" "${API_JAR}"
fi

log INFO "Compiling consent plugin"
find "${CLASSES_DIR}" -mindepth 1 -delete || true

mapfile -t sources < <(find "${PLUGIN_DIR}/src/main/java" -name '*.java' | sort)
[[ "${#sources[@]}" -gt 0 ]] || die "No Java sources found for consent plugin"

javac -encoding UTF-8 -source 21 -target 21 -cp "${API_JAR}" -d "${CLASSES_DIR}" "${sources[@]}"

if [[ -d "${PLUGIN_DIR}/src/main/resources" ]]; then
  cp -a "${PLUGIN_DIR}/src/main/resources/." "${CLASSES_DIR}/"
fi

jar --create --file "${BUILD_DIR}/bnb-consent.jar" -C "${CLASSES_DIR}" .
log INFO "Built ${BUILD_DIR}/bnb-consent.jar"

