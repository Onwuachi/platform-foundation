#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=== DEBUG: sources.list ==="
cat /etc/apt/sources.list || true
echo "=== DEBUG: sources.list.d ==="
ls -la /etc/apt/sources.list.d || true

# 🔒 Jammy apt race fix
rm -rf /var/lib/apt/lists/*
mkdir -p /var/lib/apt/lists/partial

apt-get update -o Acquire::Retries=3
apt-get install -y \
  ca-certificates \
  curl \
  unzip \
  gnupg \
  lsb-release \
  sysstat

#################################
# AWS CLI v2 (REQUIRED FOR ECR)
#################################
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

/usr/local/bin/aws --version

#################################
# Certbot user + webroot
#################################
if ! id acme >/dev/null 2>&1; then
  useradd \
    --system \
    --no-create-home \
    --shell /usr/sbin/nologin \
    acme
fi

mkdir -p /var/www/certbot
chown -R acme:acme /var/www/certbot
chmod 755 /var/www/certbot
