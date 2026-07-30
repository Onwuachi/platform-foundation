#!/bin/bash

# Usage: ./install_packages.sh <IP_ADDRESS> <KEY_PATH> <USER> <PACKAGE1> [PACKAGE2] ...
# Example: ./install_packages.sh 54.160.62.82 ~/.ssh/onwua_key.pem ubuntu python3-certbot-nginx socat

if [ "$#" -lt 4 ]; then
  echo "❌ Usage: $0 <IP_ADDRESS> <KEY_PATH> <USER> <PACKAGE1> [PACKAGE2] ..."
  exit 1
fi


IP="$1"
KEY="$2"
USER="$3"
shift 3
PACKAGES="$@"

echo "🔐 Connecting to $USER@$IP to install: $PACKAGES"

ssh -i "$KEY" -o StrictHostKeyChecking=no "$USER@$IP" <<EOF
  set -e

  echo "📦 Preparing system for package install..."
  sudo apt-get update -y
  sudo apt-get install -y software-properties-common apt-transport-https ca-certificates curl gnupg lsb-release

  echo "📦 Enabling universe repo..."
  sudo add-apt-repository universe -y
  sudo apt-get update -y

  echo "📦 Installing requested packages: $PACKAGES"
  sudo apt-get install -y $PACKAGES || {
    echo "⚠️ Some packages failed to install. Handling known cases..."

    if echo "$PACKAGES" | grep -q awscli; then
      echo "📦 Installing AWS CLI v2 manually..."
      curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
      unzip awscliv2.zip
      sudo ./aws/install
    fi

    if echo "$PACKAGES" | grep -q python3-certbot-nginx; then
      echo "📦 Trying Certbot install via snap as fallback..."
      sudo snap install core; sudo snap refresh core
      sudo snap install --classic certbot
      sudo ln -s /snap/bin/certbot /usr/bin/certbot
    fi
  }

  echo "✅ Installation complete."
EOF
