#!/bin/bash

set -e

# 🔧 Configurable variables
aws_account_id="046685909731"
aws_region="us-east-1"
ecr_repo_wordpress="onwuachi-wordpress"
mongo_uri="mongodb://your-mongo-uri"
WORDPRESS_DB_HOST="your-db-host"
WORDPRESS_DB_USER="your-db-user"
WORDPRESS_DB_PASSWORD="your-db-password"
WORDPRESS_DB_NAME="your-db-name"
DOMAIN="onwua.com"

echo "📦 Installing Docker and dependencies..."

# Install prerequisites
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key and repo
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
cat <<EOF > docker-compose.yml
services:
  wordpress:
    image: ${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com/${ecr_repo_wordpress}:latest
    container_name: wordpress
    restart: always
    ports:
      - "8080:80"
    environment:
      WORDPRESS_DB_HOST: ${WORDPRESS_DB_HOST}
      WORDPRESS_DB_USER: ${WORDPRESS_DB_USER}
      WORDPRESS_DB_PASSWORD: ${WORDPRESS_DB_PASSWORD}
      WORDPRESS_DB_NAME: ${WORDPRESS_DB_NAME}

  haproxy:
    image: haproxy:latest
    container_name: haproxy
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /etc/haproxy/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
EOF

echo "🔐 Authenticating with ECR..."
aws ecr get-login-password --region ${aws_region} | \
  docker login --username AWS --password-stdin ${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com

echo "🚀 Starting containers..."
docker compose pull
docker compose up -d

echo "📝 Writing landing page..."
cat <<HTML | sudo tee /var/www/html/index.html > /dev/null
<h1>Welcome to Onwua.com</h1>
<p>CloudOpsNinja lives here. DevOps KB & Links Coming Soon. Recipes, anime, wikis and more.</p>
HTML

echo "✅ Web stack setup complete for $DOMAIN"