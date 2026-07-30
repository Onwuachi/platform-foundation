#!/bin/bash
set -euxo pipefail

echo ">>> Updating system"
sudo apt update -y

echo ">>> Installing core packages"
sudo apt install -y \
  nginx \
  haproxy \
  certbot \
  jq \
  curl \
  unzip \
  fuser

echo ">>> Cleaning default configs"
sudo rm -f /etc/nginx/sites-enabled/default || true
sudo rm -f /etc/nginx/sites-available/default || true

echo ">>> Disable nginx (HAProxy owns port 80)"
sudo systemctl stop nginx || true
sudo systemctl disable nginx || true

echo ">>> Pre-create haproxy directory"
sudo mkdir -p /etc/haproxy
sudo chmod 755 /etc/haproxy

echo ">>> Done"
