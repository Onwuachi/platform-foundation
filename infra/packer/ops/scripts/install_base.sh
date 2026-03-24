#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=== DEBUG: sources.list ==="
cat /etc/apt/sources.list || true
echo "=== DEBUG: sources.list.d ==="
ls -la /etc/apt/sources.list.d || true

cloud-init status --wait

#################################
# Clean and prepare APT state
#################################
rm -rf /var/lib/apt/lists/*
rm -rf /var/cache/apt/*
mkdir -p /var/lib/apt/lists/partial

apt-get clean

# Disable language packs to reduce downloads
echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/99translations

# Retry metadata download (robust against transient failures)
for i in {1..5}; do
  if apt-get update; then
    break
  else
    echo "APT metadata fetch failed... retrying in 5s"
    sleep 5
  fi
done

#################################
# Install core packages
#################################
apt-get install -y \
  ca-certificates \
  curl \
  unzip \
  gnupg \
  lsb-release \
  sysstat

#################################
# Pre-warm apt cache for future installs
#################################
apt-get install --download-only -y \
  ca-certificates \
  curl \
  unzip \
  gnupg \
  lsb-release \
  sysstat

# Remove locks but keep cached metadata
rm -f /var/lib/dpkg/lock
rm -f /var/lib/dpkg/lock-frontend
rm -f /var/cache/apt/archives/lock

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

###Base Directory for certbot
mkdir -p /var/www/certbot
chown -R acme:acme /var/www/certbot
chmod 755 /var/www/certbot

###Base Directory for platform API
mkdir -p /etc/platform
mkdir -p /etc/platform/services
mkdir -p /etc/haproxy/services

cat >/etc/platform/api.env <<EOF
IMAGE_URI=046685909731.dkr.ecr.us-east-1.amazonaws.com/api:latest
PORT=3000
NODE_ENV=production
EOF

