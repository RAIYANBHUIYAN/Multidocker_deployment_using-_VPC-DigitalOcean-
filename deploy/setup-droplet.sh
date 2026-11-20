#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "run as root" >&2
  exit 1
fi

. /etc/os-release
if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
  echo "Ubuntu 24.04 LTS required" >&2
  exit 1
fi

if [[ -z "${CI_STAGING_PUBKEY:-}" || -z "${CI_PRODUCTION_PUBKEY:-}" ]]; then
  echo "set CI_STAGING_PUBKEY and CI_PRODUCTION_PUBKEY" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl nginx fail2ban unattended-upgrades

if ! command -v containerd >/dev/null || ! command -v nerdctl >/dev/null; then
  echo "containerd and nerdctl must already be installed on this host" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install -d -m 755 /opt/app /opt/app/state
install -m 755 "${SCRIPT_DIR}/deploy.sh" /opt/app/deploy.sh
install -m 644 "${SCRIPT_DIR}/nginx/api.conf" /etc/nginx/sites-available/api.conf

ln -sfn /etc/nginx/sites-available/api.conf /etc/nginx/sites-enabled/api.conf
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx
systemctl reload nginx

if ! id -u deploy >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash deploy
fi

# Rootful nerdctl via passwordless sudo for deploy commands only
cat >/etc/sudoers.d/deploy-nerdctl <<'EOF'
deploy ALL=(root) NOPASSWD: /usr/bin/nerdctl, /usr/local/bin/nerdctl
EOF
chmod 440 /etc/sudoers.d/deploy-nerdctl

# Make deploy.sh call sudo nerdctl when not root
if ! grep -q 'nerdctl()' /opt/app/deploy.sh; then
  sed -i '2a\
if [[ "$(id -u)" -ne 0 ]]; then\
  nerdctl() { sudo nerdctl "$@"; }\
fi' /opt/app/deploy.sh
fi

install -d -m 755 -o root -g root /home/deploy/.ssh
AUTH_KEYS=/home/deploy/.ssh/authorized_keys
cat >"$AUTH_KEYS" <<EOF
command="/opt/app/deploy.sh staging",restrict ${CI_STAGING_PUBKEY}
command="/opt/app/deploy.sh production",restrict ${CI_PRODUCTION_PUBKEY}
EOF
chown root:root "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"
chown deploy:deploy /opt/app/state

mkdir -p /etc/ssh/sshd_config.d
cat >/etc/ssh/sshd_config.d/00-hardening.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
EOF
sshd -t
systemctl reload ssh || systemctl reload sshd

systemctl enable --now fail2ban
systemctl enable --now unattended-upgrades

echo "setup complete"