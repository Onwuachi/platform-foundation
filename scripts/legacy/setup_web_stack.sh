#!/bin/bash

set -e

echo "📦 Installing packages..."
sudo apt update -y
sudo apt install -y docker.io docker-compose awscli certbot python3-certbot-nginx

echo "🔧 Enabling Docker..."
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ubuntu

echo "📁 Creating Docker Compose directory..."
mkdir -p /home/ubuntu/compose
cd /home/ubuntu/compose

echo "📝 Writing Docker Compose file..."
cat <<EOF > docker-compose.yml
version: '3.8'
services:
  node_app:
    image: ${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com/${ecr_repo_node}:latest
    container_name: node_app
    restart: always
    ports:
      - "3000:3000"
    environment:
      - MONGO_URI=${mongo_uri}

  go_api:
    image: ${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com/${ecr_repo_go}:latest
    container_name: go_api
    restart: always
    ports:
      - "4000:4000"

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
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com

echo "🚀 Starting containers..."
docker compose pull
docker compose up -d

echo "📝 Writing landing page..."
cat <<HTML | sudo tee /var/www/html/index.html > /dev/null
<h1>Welcome to Onwuachi.com</h1>
<p>The CloudNinja that gives you DevOps KB & Links Coming Soon. Top list for recipes, anime, wikis and more.</p>
HTML

echo "✅ Web stack setup complete."