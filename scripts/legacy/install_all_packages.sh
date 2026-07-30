#!/bin/bash

# Usage:
# ./install_packages.sh <IP_ADDRESS> <KEY_PATH> <USER> <SERVICE> <EXTRA_PACKAGES...>
# Example:
# ./install_packages.sh 54.160.62.82 ~/.ssh/onwua_key.pem ubuntu docker awscli python3-certbot-nginx

IP="$1"
KEY="$2"
USER="$3"
SERVICE="$4"
shift 4
EXTRAS="$@"

if [ -z "$IP" ] || [ -z "$KEY" ] || [ -z "$USER" ] || [ -z "$SERVICE" ]; then
  echo "❌ Missing required arguments."
  echo "Usage: ./install_packages.sh <IP_ADDRESS> <KEY_PATH> <USER> <SERVICE> <EXTRA_PACKAGES...>"
  exit 1
fi

echo "🔐 Connecting to $USER@$IP to install: $SERVICE + [$EXTRAS]"

ssh -i "$KEY" -o StrictHostKeyChecking=no "$USER@$IP" <<EOF
  set -e

  echo "📦 Updating system..."
  sudo apt-get update -y
  sudo apt-get install -y software-properties-common apt-transport-https ca-certificates curl gnupg lsb-release unzip net-tools gdb

  echo "📦 Enabling universe repo..."
  sudo add-apt-repository universe -y
  sudo apt-get update -y

  echo "📦 Installing extra packages: $EXTRAS"
  sudo apt-get install -y $EXTRAS || {
    echo "⚠️ Some packages failed. Handling known fallbacks..."

    if echo "$EXTRAS" | grep -q awscli; then
      echo "📦 Installing AWS CLI v2 manually..."
      curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
      unzip awscliv2.zip
      sudo ./aws/install
    fi

    if echo "$EXTRAS" | grep -q python3-certbot-nginx; then
      echo "📦 Trying Certbot via Snap fallback..."
      sudo snap install core; sudo snap refresh core
      sudo snap install --classic certbot
      sudo ln -s /snap/bin/certbot /usr/bin/certbot
    fi
  }

  echo "🔧 Installing selected service: $SERVICE"
  case "$SERVICE" in
    docker)
      sudo apt-get install -y docker.io
      sudo systemctl enable docker
      sudo systemctl start docker
      sudo usermod -aG docker $USER
      ;;
    nginx)
      sudo apt-get install -y nginx
      sudo systemctl enable nginx
      sudo systemctl start nginx
      ;;
    haproxy)
      sudo apt-get install -y haproxy
      sudo systemctl enable haproxy
      sudo systemctl start haproxy
      ;;
    apache2)
      sudo apt-get install -y apache2
      sudo systemctl enable apache2
      sudo systemctl start apache2
      ;;
    *)
      echo "❌ Unknown service: $SERVICE"
      exit 1
      ;;
  esac

  echo "✅ $SERVICE installed and running. Extras installed as needed."
EOF