#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run with sudo: sudo bash Ubuntu2204/scripts/install-docker-cn.sh"
  exit 1
fi

REAL_USER="${SUDO_USER:-${USER:-}}"
DOCKER_APT_MIRROR="${DOCKER_APT_MIRROR:-https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu}"
UBUNTU_CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"

echo "Using Ubuntu codename: ${UBUNTU_CODENAME}"
echo "Using Docker apt mirror: ${DOCKER_APT_MIRROR}"

apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release

install -m 0755 -d /etc/apt/keyrings
curl -fsSL "${DOCKER_APT_MIRROR}/gpg" -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

cat >/etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] ${DOCKER_APT_MIRROR} ${UBUNTU_CODENAME} stable
EOF

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

install -m 0755 -d /etc/docker
if [ -f /etc/docker/daemon.json ]; then
  cp /etc/docker/daemon.json "/etc/docker/daemon.json.bak.$(date +%Y%m%d%H%M%S)"
fi

cat >/etc/docker/daemon.json <<'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1ms.run",
    "https://dockerproxy.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF

systemctl enable docker
systemctl restart docker

if [ -n "${REAL_USER}" ] && id "${REAL_USER}" >/dev/null 2>&1; then
  usermod -aG docker "${REAL_USER}"
  echo "Added ${REAL_USER} to docker group. Log out and log back in, or run: newgrp docker"
fi

docker --version
docker compose version
docker info | sed -n '/Registry Mirrors:/,/Live Restore Enabled:/p'

echo "Docker installation finished."
