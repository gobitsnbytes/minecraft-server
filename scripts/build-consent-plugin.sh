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
PAPER_API_VERSION="${PAPER_API_VERSION:-1.21.11-R0.1-SNAPSHOT}"
PAPER_API_BOM_VERSION="${PAPER_API_BOM_VERSION:-4.26.1}"

[[ -d "${PLUGIN_DIR}/src/main/java" ]] || die "Missing plugin source tree: ${PLUGIN_DIR}"
ensure_dir "${CLASSES_DIR}" 0755
ensure_dir "${LIB_DIR}" 0755

[[ -f "${SERVER_JAR}" ]] || die "Missing server jar for compilation: ${SERVER_JAR}"

download_maven_jar() {
  local group_path="$1"
  local artifact="$2"
  local version="$3"
  local destination="$4"

  [[ -f "${destination}" ]] && return 0
  download_file "https://repo.papermc.io/repository/maven-public/${group_path}/${artifact}/${version}/${artifact}-${version}.jar" "${destination}"
}

API_JAR="${LIB_DIR}/paper-api-${PAPER_API_VERSION}.jar"
if [[ ! -f "${API_JAR}" ]]; then
  if [[ "${PAPER_API_VERSION}" == *SNAPSHOT ]]; then
    snapshot_metadata_url="https://repo.papermc.io/repository/maven-public/io/papermc/paper/paper-api/${PAPER_API_VERSION}/maven-metadata.xml"
    snapshot_timestamp="$(curl -fsSL "${snapshot_metadata_url}" | awk '
      /<snapshot>/ {in_snapshot=1}
      in_snapshot && /<timestamp>/ {
        sub(/.*<timestamp>/, "")
        sub(/<\/timestamp>.*/, "")
        print
        exit
      }
      /<\/snapshot>/ {in_snapshot=0}
    ')"
    snapshot_build="$(curl -fsSL "${snapshot_metadata_url}" | awk '
      /<snapshot>/ {in_snapshot=1}
      in_snapshot && /<buildNumber>/ {
        sub(/.*<buildNumber>/, "")
        sub(/<\/buildNumber>.*/, "")
        print
        exit
      }
      /<\/snapshot>/ {in_snapshot=0}
    ')"
    [[ -n "${snapshot_timestamp}" && -n "${snapshot_build}" ]] || die "Unable to resolve snapshot jar for ${PAPER_API_VERSION}"
    snapshot_jar_version="${PAPER_API_VERSION%-SNAPSHOT}-${snapshot_timestamp}-${snapshot_build}"
    log INFO "Downloading Paper API ${snapshot_jar_version}"
    download_file "https://repo.papermc.io/repository/maven-public/io/papermc/paper/paper-api/${PAPER_API_VERSION}/paper-api-${snapshot_jar_version}.jar" "${API_JAR}"
  else
    log INFO "Downloading Paper API ${PAPER_API_VERSION}"
    download_file "https://repo.papermc.io/repository/maven-public/io/papermc/paper/paper-api/${PAPER_API_VERSION}/paper-api-${PAPER_API_VERSION}.jar" "${API_JAR}"
  fi
fi

download_maven_jar "net/kyori" "adventure-api" "${PAPER_API_BOM_VERSION}" "${LIB_DIR}/adventure-api-${PAPER_API_BOM_VERSION}.jar"
download_maven_jar "net/kyori" "adventure-text-minimessage" "${PAPER_API_BOM_VERSION}" "${LIB_DIR}/adventure-text-minimessage-${PAPER_API_BOM_VERSION}.jar"
download_maven_jar "net/kyori" "adventure-text-serializer-gson" "${PAPER_API_BOM_VERSION}" "${LIB_DIR}/adventure-text-serializer-gson-${PAPER_API_BOM_VERSION}.jar"
download_maven_jar "net/kyori" "adventure-text-serializer-legacy" "${PAPER_API_BOM_VERSION}" "${LIB_DIR}/adventure-text-serializer-legacy-${PAPER_API_BOM_VERSION}.jar"
download_maven_jar "net/kyori" "adventure-text-serializer-plain" "${PAPER_API_BOM_VERSION}" "${LIB_DIR}/adventure-text-serializer-plain-${PAPER_API_BOM_VERSION}.jar"
download_maven_jar "net/kyori" "adventure-text-logger-slf4j" "${PAPER_API_BOM_VERSION}" "${LIB_DIR}/adventure-text-logger-slf4j-${PAPER_API_BOM_VERSION}.jar"
download_maven_jar "net/md-5" "bungeecord-chat" "1.21-R0.2-deprecated+build.21" "${LIB_DIR}/bungeecord-chat-1.21-R0.2-deprecated+build.21.jar"
download_maven_jar "com/google/guava" "guava" "33.3.1-jre" "${LIB_DIR}/guava-33.3.1-jre.jar"
download_maven_jar "com/google/code/gson" "gson" "2.11.0" "${LIB_DIR}/gson-2.11.0.jar"
download_maven_jar "org/yaml" "snakeyaml" "2.2" "${LIB_DIR}/snakeyaml-2.2.jar"
download_maven_jar "org/joml" "joml" "1.10.8" "${LIB_DIR}/joml-1.10.8.jar"
download_maven_jar "it/unimi/dsi" "fastutil" "8.5.15" "${LIB_DIR}/fastutil-8.5.15.jar"
download_maven_jar "org/apache/logging/log4j" "log4j-api" "2.24.1" "${LIB_DIR}/log4j-api-2.24.1.jar"
download_maven_jar "org/slf4j" "slf4j-api" "2.0.16" "${LIB_DIR}/slf4j-api-2.0.16.jar"
download_maven_jar "com/mojang" "brigadier" "1.3.10" "${LIB_DIR}/brigadier-1.3.10.jar"
download_maven_jar "org/apache/maven" "maven-resolver-provider" "3.9.6" "${LIB_DIR}/maven-resolver-provider-3.9.6.jar"
download_maven_jar "org/jspecify" "jspecify" "1.0.0" "${LIB_DIR}/jspecify-1.0.0.jar"
download_maven_jar "org/checkerframework" "checker-qual" "3.49.2" "${LIB_DIR}/checker-qual-3.49.2.jar"

log INFO "Compiling consent plugin"
find "${CLASSES_DIR}" -mindepth 1 -delete || true

mapfile -t sources < <(find "${PLUGIN_DIR}/src/main/java" -name '*.java' | sort)
[[ "${#sources[@]}" -gt 0 ]] || die "No Java sources found for consent plugin"

classpath_entries=("${API_JAR}")
while IFS= read -r -d '' jar_path; do
  classpath_entries+=("${jar_path}")
done < <(find "${LIB_DIR}" -name '*.jar' -print0 | sort -z)

javac -encoding UTF-8 --release 21 -cp "$(IFS=:; printf '%s' "${classpath_entries[*]}")" -d "${CLASSES_DIR}" "${sources[@]}"

if [[ -d "${PLUGIN_DIR}/src/main/resources" ]]; then
  cp -a "${PLUGIN_DIR}/src/main/resources/." "${CLASSES_DIR}/"
fi

jar --create --file "${BUILD_DIR}/bnb-consent.jar" -C "${CLASSES_DIR}" .
log INFO "Built ${BUILD_DIR}/bnb-consent.jar"
