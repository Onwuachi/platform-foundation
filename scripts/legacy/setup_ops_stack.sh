#!/bin/bash
set -e

DOMAIN="onwuachi.com"
EMAIL="admin@$DOMAIN"
PEM_PATH="/etc/letsencrypt/live/$DOMAIN/haproxy.pem"

echo "== SSL + HAProxy Setup on $(hostname) =="

sudo apt update -y
sudo apt install -y snapd
sudo snap install core && sudo snap refresh core
sudo snap install --classic certbot
sudo ln -sf /snap/bin/certbot /usr/bin/certbot

echo "Checking DNS..."
PUBLIC_IP=$(curl -s ifconfig.me)
DNS_IP=$(dig +short $DOMAIN)

echo "Public: $PUBLIC_IP"
echo "DNS:    $DNS_IP"

if [[ "$PUBLIC_IP" != "$DNS_IP" ]]; then
  echo "❌ DNS does NOT point to this server."
  exit 1
fi

echo "Stopping HAProxy/Nginx..."
sudo systemctl stop haproxy || true
sudo systemctl stop nginx || true

echo "Requesting certificate..."
sudo certbot certonly --standalone \
  -d $DOMAIN -d www.$DOMAIN \
  --agree-tos -m $EMAIL \
  --non-interactive

sudo mkdir -p /etc/letsencrypt/live/$DOMAIN
sudo bash -c "cat /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/letsencrypt/live/$DOMAIN/privkey.pem > $PEM_PATH"
sudo chmod 600 $PEM_PATH

if [[ ! -f "$PEM_PATH" ]]; then
  echo "❌ PEM file missing"
  exit 1
fi

echo "Patching HAProxy..."
sudo tee /etc/haproxy/haproxy.cfg >/dev/null <<EOF
global
    log /dev/log local0
    maxconn 2000
    daemon

defaults
    log global
    mode http
    timeout connect 5s
    timeout client  50s
    timeout server  50s

frontend http_in
    bind *:80
    redirect scheme https code 301 if !{ ssl_fc }

frontend https_in
    bind *:443 ssl crt $PEM_PATH
    mode http

    acl is_admin path_beg /admin
    acl is_api   path_beg /api
    acl is_wp    path_beg /wp

    use_backend admin_backend if is_admin
    use_backend api_backend   if is_api
    use_backend wp_backend    if is_wp

    default_backend web_backend

backend web_backend
    server web1 3.88.14.71:8080 check

backend admin_backend
    server admin1 54.161.22.92:80 check

backend api_backend
    server api1 52.1.141.247:3000 check

backend wp_backend
    server wp1 3.87.238.44:80 check
EOF

echo "Restarting HAProxy..."
sudo systemctl restart haproxy

echo "SSL + HAProxy setup complete."
