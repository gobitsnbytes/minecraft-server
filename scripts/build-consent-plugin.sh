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
SERVER_JAR="${SERVER_JAR:-/home/minecraft/server/server.jar}"
PAPER_API_PREFIX="${PAPER_API_PREFIX:-1.21.11}"
MAVEN_METADATA_URL="${MAVEN_METADATA_URL:-https://repo.papermc.io/repository/maven-public/io/papermc/paper/paper-api/maven-metadata.xml}"

[[ -d "${PLUGIN_DIR}/src/main/java" ]] || die "Missing plugin source tree: ${PLUGIN_DIR}"
ensure_dir "${CLASSES_DIR}" 0755
ensure_dir "${LIB_DIR}" 0755

[[ -f "${SERVER_JAR}" ]] || die "Missing server jar for compilation: ${SERVER_JAR}"

log INFO "Resolving Paper API version for ${PAPER_API_PREFIX}"
api_version="$(
  curl -fsSL "${MAVEN_METADATA_URL}" \
    | grep -oE "<version>${PAPER_API_PREFIX}\.build\.[0-9]+-stable</version>" \
    | tail -n 1 \
    | sed 's#</\?version>##g'
)"
[[ -n "${api_version}" ]] || die "Unable to resolve Paper API version for ${PAPER_API_PREFIX}"

API_JAR="${LIB_DIR}/paper-api-${api_version}.jar"
if [[ ! -f "${API_JAR}" ]]; then
  log INFO "Downloading Paper API ${api_version}"
  download_file "https://repo.papermc.io/repository/maven-public/io/papermc/paper/paper-api/${api_version}/paper-api-${api_version}.jar" "${API_JAR}"
fi

log INFO "Compiling consent plugin"
find "${CLASSES_DIR}" -mindepth 1 -delete || true

mapfile -t sources < <(find "${PLUGIN_DIR}/src/main/java" -name '*.java' | sort)
[[ "${#sources[@]}" -gt 0 ]] || die "No Java sources found for consent plugin"

javac -encoding UTF-8 --release 21 -cp "${API_JAR}" -d "${CLASSES_DIR}" "${sources[@]}"

if [[ -d "${PLUGIN_DIR}/src/main/resources" ]]; then
  cp -a "${PLUGIN_DIR}/src/main/resources/." "${CLASSES_DIR}/"
fi

jar --create --file "${BUILD_DIR}/bnb-consent.jar" -C "${CLASSES_DIR}" .
log INFO "Built ${BUILD_DIR}/bnb-consent.jar"
