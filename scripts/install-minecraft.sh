#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
require_command curl
require_command jq
require_command install
require_command python3

MINECRAFT_USER="${MINECRAFT_USER:-minecraft}"
SERVER_ROOT="${SERVER_ROOT:-/home/minecraft/server}"
SERVER_RELEASES="${SERVER_RELEASES:-${SERVER_ROOT}/releases}"
SERVER_CONFIGS="${SERVER_CONFIGS:-${SERVER_ROOT}/configs}"
SERVER_PLUGINS="${SERVER_PLUGINS:-${SERVER_ROOT}/plugins}"
SERVER_LOGS="${SERVER_LOGS:-${SERVER_ROOT}/logs}"
SERVER_BACKUPS="${SERVER_BACKUPS:-${SERVER_ROOT}/backups}"
SERVER_CACHE="${SERVER_CACHE:-${SERVER_ROOT}/cache}"
SERVER_TEMP="${SERVER_TEMP:-${SERVER_ROOT}/temp}"
SERVER_SCRIPTS="${SERVER_SCRIPTS:-${SERVER_ROOT}/scripts}"

PURPUR_API_ROOT="https://api.purpurmc.org/v2/purpur"
PURPUR_VERSION="${PURPUR_VERSION:-1.21.11}"
PURPUR_BUILD="${PURPUR_BUILD:-latest}"
PURPUR_RELEASE_DIR="${SERVER_RELEASES}/purpur-${PURPUR_VERSION}-${PURPUR_BUILD}-$(timestamp)"

MOTD_TITLE="${MOTD_TITLE:-bits&bytes Minecraft Server}"
MOTD_SUBTITLE="${MOTD_SUBTITLE:-Official Foundation-operated service | gobitsnbytes.org}"

log INFO "Creating directory tree"
for dir in \
  "${SERVER_ROOT}" \
  "${SERVER_RELEASES}" \
  "${SERVER_CONFIGS}" \
  "${SERVER_PLUGINS}" \
  "${SERVER_LOGS}" \
  "${SERVER_BACKUPS}" \
  "${SERVER_CACHE}" \
  "${SERVER_TEMP}" \
  "${SERVER_SCRIPTS}"; do
  ensure_dir "$dir" 0750
done

chown -R "${MINECRAFT_USER}:${MINECRAFT_USER}" "${SERVER_ROOT}"

log INFO "Copying configuration templates into place"
cp -a "${PROJECT_ROOT}/config/." "${SERVER_CONFIGS}/"

log INFO "Downloading latest Purpur build"
ensure_dir "${PURPUR_RELEASE_DIR}" 0750

purpur_meta="$(mktemp)"
curl -fsSL "${PURPUR_API_ROOT}" -o "${purpur_meta}" || die "Unable to query Purpur API"

if [[ "${PURPUR_VERSION}" == "latest" ]]; then
  PURPUR_VERSION="$(jq -r '.versions[-1]' "${purpur_meta}")"
fi
rm -f "${purpur_meta}"

purpur_version_meta="$(mktemp)"
curl -fsSL "${PURPUR_API_ROOT}/${PURPUR_VERSION}" -o "${purpur_version_meta}" || die "Unable to query Purpur API for ${PURPUR_VERSION}"

if [[ "${PURPUR_BUILD}" == "latest" ]]; then
  PURPUR_BUILD="$(jq -r '.builds.latest // .latestBuild // .build' "${purpur_version_meta}")"
fi
rm -f "${purpur_version_meta}"

purpur_download_url="${PURPUR_API_ROOT}/${PURPUR_VERSION}/${PURPUR_BUILD}/download"

download_file "${purpur_download_url}" "${PURPUR_RELEASE_DIR}/purpur.jar"
ln -sfn "${PURPUR_RELEASE_DIR}/purpur.jar" "${SERVER_ROOT}/server.jar"

log INFO "Writing initial server environment"
cat >"${SERVER_CONFIGS}/server.env" <<EOF
JAVA_BIN=/usr/bin/java
JAVA_XMS=4G
JAVA_XMX=5G
JAVA_GC_FLAGS="-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+AlwaysPreTouch -XX:+UseStringDeduplication -XX:+DisableExplicitGC"
JAVA_EXTRA_FLAGS="-Dfile.encoding=UTF-8 -Dterminal.jline=false -Dterminal.ansi=true"
SERVER_JAR=${SERVER_ROOT}/server.jar
SERVER_USER=${MINECRAFT_USER}
SERVER_GROUP=${MINECRAFT_USER}
SERVER_WORKDIR=${SERVER_ROOT}
RCON_HOST=127.0.0.1
RCON_PORT=25575
RCON_PASSWORD=$(python3 - <<'PY'
import secrets
print(secrets.token_hex(16))
PY
)
SERVER_MOTD="${MOTD_TITLE} | ${MOTD_SUBTITLE}"
EOF
chmod 0640 "${SERVER_CONFIGS}/server.env"
chown root:"${MINECRAFT_USER}" "${SERVER_CONFIGS}/server.env"

log INFO "Writing server.properties"
cat >"${SERVER_ROOT}/server.properties" <<'EOF'
enable-jmx-monitoring=false
rcon.port=25575
enable-rcon=true
rcon.password=CHANGE_ME_AFTER_INSTALL
enable-query=false
gamemode=survival
force-gamemode=false
difficulty=normal
hardcore=false
allow-flight=true
pvp=true
spawn-protection=16
max-players=20
view-distance=8
simulation-distance=6
network-compression-threshold=512
online-mode=false
prevent-proxy-connections=true
enforce-secure-profile=false
allow-nether=true
level-name=world
motd=bits&bytes Minecraft Server | official Foundation-operated service
white-list=false
pause-when-empty-seconds=-1
EOF
chmod 0640 "${SERVER_ROOT}/server.properties"

log INFO "Writing MOTD and policy text"
cat >"${SERVER_CONFIGS}/motd.txt" <<'EOF'
bits&bytes Minecraft Server
Official Foundation-operated service
Policies: gobitsnbytes.org/coc | gobitsnbytes.org/privacy | gobitsnbytes.org/terms
EOF

cat >"${SERVER_CONFIGS}/first-join.txt" <<'EOF'
Welcome to the official bits&bytes Minecraft Server.

This is an official digital fork of GOBITSNBYTES FOUNDATION.

Important:
- Player safety matters.
- Personal payments to staff are prohibited.
- Official policies live on the Foundation website.

Read:
- https://gobitsnbytes.org/coc
- https://gobitsnbytes.org/privacy
- https://gobitsnbytes.org/terms
EOF

log INFO "Installing systemd unit and timers"
install -d -m 0755 /etc/systemd/system
install -m 0644 "${PROJECT_ROOT}/systemd/bnb-minecraft.service" /etc/systemd/system/bnb-minecraft.service
install -m 0644 "${PROJECT_ROOT}/systemd/bnb-backup.service" /etc/systemd/system/bnb-backup.service
install -m 0644 "${PROJECT_ROOT}/systemd/bnb-backup.timer" /etc/systemd/system/bnb-backup.timer
install -m 0644 "${PROJECT_ROOT}/systemd/bnb-health.service" /etc/systemd/system/bnb-health.service
install -m 0644 "${PROJECT_ROOT}/systemd/bnb-health.timer" /etc/systemd/system/bnb-health.timer
systemctl daemon-reload

log INFO "Building consent plugin"
bash "${PROJECT_ROOT}/scripts/build-consent-plugin.sh"
install -d -m 0750 "${SERVER_PLUGINS}"
install -m 0644 "${PROJECT_ROOT}/plugins/consent-plugin/build/bnb-consent.jar" "${SERVER_PLUGINS}/bnb-consent.jar"

if [[ "${INSTALL_FULL_PLUGIN_STACK:-0}" == "1" ]]; then
  log INFO "Installing full plugin stack"
  bash "${PROJECT_ROOT}/scripts/install-plugins.sh"
fi

log INFO "Installing local helper scripts"
cp -a "${PROJECT_ROOT}/scripts/." "${SERVER_SCRIPTS}/"
chmod +x "${SERVER_SCRIPTS}"/*.sh "${SERVER_SCRIPTS}/lib/rcon.py"
chown -R "${MINECRAFT_USER}:${MINECRAFT_USER}" "${SERVER_ROOT}"
chown root:root "${SERVER_CONFIGS}/server.env"
chmod 0640 "${SERVER_CONFIGS}/server.env"

log INFO "Enabling services"
systemctl enable bnb-minecraft.service
systemctl enable bnb-backup.timer
systemctl enable bnb-health.timer

log INFO "Minecraft runtime installed"
log INFO "Next step: install plugins and then start the service for first boot."
