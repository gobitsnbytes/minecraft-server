#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root
require_command apt-get
require_command systemctl
require_command timedatectl
require_command locale-gen
require_command visudo

export DEBIAN_FRONTEND=noninteractive

HOSTNAME_VALUE="${HOSTNAME_VALUE:-bitsnbytesMC}"
TIMEZONE_VALUE="${TIMEZONE_VALUE:-Asia/Kolkata}"
LOCALE_VALUE="${LOCALE_VALUE:-en_US.UTF-8}"
ADMIN_USER="${ADMIN_USER:-bnbadmin}"
MINECRAFT_USER="${MINECRAFT_USER:-minecraft}"
SWAP_SIZE="${SWAP_SIZE:-2G}"

log INFO "Updating package lists"
apt-get update
apt-get -y full-upgrade

log INFO "Installing host hardening packages"
apt-get install -y --no-install-recommends \
  ca-certificates \
  chrony \
  curl \
  fail2ban \
  gnupg \
  jq \
  logrotate \
  iproute2 \
  net-tools \
  openssh-server \
  openssl \
  rsync \
  sudo \
  unattended-upgrades \
  ufw \
  unzip \
  zstd

log INFO "Configuring hostname, timezone, and locale"
hostnamectl set-hostname "${HOSTNAME_VALUE}"
timedatectl set-timezone "${TIMEZONE_VALUE}"
sed -i "s/^# *${LOCALE_VALUE} UTF-8/${LOCALE_VALUE} UTF-8/" /etc/locale.gen || true
grep -q "^${LOCALE_VALUE} UTF-8" /etc/locale.gen || echo "${LOCALE_VALUE} UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG="${LOCALE_VALUE}" LC_ALL="${LOCALE_VALUE}"

log INFO "Creating administrator account if needed"
if ! id -u "${ADMIN_USER}" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "${ADMIN_USER}"
  usermod -aG sudo "${ADMIN_USER}"
fi

log INFO "Creating minecraft service account if needed"
if ! id -u "${MINECRAFT_USER}" >/dev/null 2>&1; then
  adduser --system --home "/home/${MINECRAFT_USER}" --shell /usr/sbin/nologin --group "${MINECRAFT_USER}"
fi

log INFO "Writing SSH hardening drop-in"
install -d -m 0755 /etc/ssh/sshd_config.d
cat >/etc/ssh/sshd_config.d/10-bnb-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
X11Forwarding no
AllowAgentForwarding yes
PermitEmptyPasswords no
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 30
MaxAuthTries 3
EOF
sshd -t
systemctl enable --now ssh
systemctl reload ssh

log INFO "Configuring unattended upgrades"
cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
Apt::Periodic::Update-Package-Lists "1";
Apt::Periodic::Unattended-Upgrade "1";
EOF
DEBIAN_CODENAME="$(. /etc/os-release && printf '%s' "${VERSION_CODENAME}")"
cat >/etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Origins-Pattern {
  "origin=Debian,codename=${DEBIAN_CODENAME},label=Debian-Security";
  "origin=Debian,codename=${DEBIAN_CODENAME},label=Debian";
};
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF

log INFO "Configuring journald retention"
install -d -m 0755 /etc/systemd/journald.conf.d
cat >/etc/systemd/journald.conf.d/10-bnb.conf <<'EOF'
[Journal]
SystemMaxUse=250M
RuntimeMaxUse=64M
MaxRetentionSec=1month
Compress=yes
EOF
systemctl restart systemd-journald

log INFO "Configuring fail2ban"
cat >/etc/fail2ban/jail.d/10-bnb-sshd.conf <<'EOF'
[sshd]
enabled = true
backend = systemd
maxretry = 5
bantime = 1h
findtime = 10m
EOF
systemctl enable --now fail2ban

log INFO "Configuring UFW"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 25565/tcp
ufw allow 19132/udp
ufw --force enable

log INFO "Configuring time sync"
systemctl enable --now chrony

log INFO "Applying safe kernel tuning"
cat >/etc/sysctl.d/99-bnb-minecraft.conf <<'EOF'
vm.swappiness = 10
vm.vfs_cache_pressure = 50
fs.file-max = 2097152
net.core.somaxconn = 4096
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 15
EOF
sysctl --system

log INFO "Creating swapfile if needed"
if ! swapon --show | grep -q '^/swapfile'; then
  if [ ! -f /swapfile ]; then
    fallocate -l "${SWAP_SIZE}" /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
  fi
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  swapon /swapfile
fi

log INFO "Disabling a few unnecessary services when present"
for svc in avahi-daemon cups bluetooth ModemManager rpcbind; do
  if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1; then
    systemctl disable --now "${svc}.service" || true
  fi
done

log INFO "Ensuring sudo is configured for the admin group"
install -d -m 0750 /etc/sudoers.d
cat >/etc/sudoers.d/10-bnb-admin <<EOF
%sudo ALL=(ALL:ALL) ALL
EOF
chmod 0440 /etc/sudoers.d/10-bnb-admin
visudo -cf /etc/sudoers >/dev/null

log INFO "Bootstrap complete"
log INFO "Reboot is recommended after first bootstrap if kernel or SSH settings changed."
