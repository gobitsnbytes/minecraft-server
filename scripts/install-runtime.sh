#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

require_root
export DEBIAN_FRONTEND=noninteractive

log INFO "Installing Java 21 and utility packages"
apt-get update
apt-get install -y --no-install-recommends wget apt-transport-https gpg
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor | tee /etc/apt/trusted.gpg.d/adoptium.gpg >/dev/null
echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" > /etc/apt/sources.list.d/adoptium.list
apt-get update
apt-get install -y --no-install-recommends \
  jq \
  temurin-21-jdk-headless \
  procps \
  python3 \
  rsync \
  tar \
  unzip \
  wget \
  xz-utils \
  zstd

java -version
