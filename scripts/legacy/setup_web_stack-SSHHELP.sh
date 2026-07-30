#!/bin/bash

# Usage:
# ./setup_web_stack.sh <IP_ADDRESS> <KEY_PATH> <USER>
# Example:
# ./setup_web_stack.sh 54.160.62.82 ~/.ssh/onwua_key.pem ubuntu

IP="$1"
KEY="$2"
USER="$3"

if [ -z "$IP" ] || [ -z "$KEY" ] || [ -z "$USER" ]; then
  echo "❌ Missing arguments. Usage: ./setup_web_stack.sh <IP_ADDRESS> <KEY_PATH> <USER>"
  exit 1
fi

echo "🔐 Connecting to $USER@$IP to run web stack setup..."

ssh -i "$KEY" -o StrictHostKeyChecking=no "$USER@$IP" <<'EOF'
  set -e

  echo "📦 Installing Docker and dependencies..."

  # Install prerequisites
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg lsb-release

  # Add Docker's official GPG key and repo (non-interactive)
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor | sudo tee /etc/apt/keyrings/docker.gpg > /dev/null

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update -y

  # Install Docker and Compose plugin
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin awscli certbot python3-certbot-nginx

  echo "🔧 Enabling Docker..."
  sudo systemctl enable docker
  sudo systemctl start docker
  sudo usermod -aG docker ubuntu

  echo "📁 Creating Docker Compose directory..."
  mkdir -p /home/ubuntu/compose
  cd /home/ubuntu/compose

  echo "📝 Writing Docker Compose file..."
  cat <<COMPOSE > docker-compose.yml
services:
  node_app:
    image: yourdockerhubusername/node-app:latest
    container_name: node_app
    restart: always
    ports:
      - "3000:3000"
    environment:
      MONGO_URI: your-mongo-uri

  go_api:
    image: yourdockerhubusername/go-api:latest
    container_name: go_api
    restart: always
    ports:
      - "4000:4000"

  wordpress:
    image: 046685909731.dkr.ecr.us-east-1.amazonaws.com/onwuachi-wordpress:latest
    container_name: wordpress
    restart: always
    ports:
      - "8080:80"
    environment:
      WORDPRESS_DB_HOST: your-db-host
      WORDPRESS_DB_USER: your-db-user
      WORDPRESS_DB_PASSWORD: your-db-password
      WORDPRESS_DB_NAME: your-db-name

  haproxy:
    image: haproxy:latest
    container_name: haproxy
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /etc/haproxy/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
COMPOSE

  echo "🔐 Authenticating with ECR..."
  aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin 046685909731.dkr.ecr.us-east-1.amazonaws.com

  echo "🚀 Starting containers..."
  docker compose pull
  docker compose up -d

  echo "📝 Writing landing page..."
  echo '<h1>Welcome to Onwuachi.com</h1><p>DevOps KB & Links Coming Soon. Welcome to CloudOpsNinja — be great and thankful. Live n Let Live.</p>' | sudo tee /var/www/html/index.html > /dev/null

  echo "✅ Web stack setup complete."
EOF