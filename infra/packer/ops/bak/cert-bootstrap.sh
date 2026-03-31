#!/usr/bin/env bash
set -e

DOMAIN="onwuachi.com"

if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
  echo "Cert exists — skipping bootstrap"
  exit 0
fi

echo "Requesting new cert via webroot..."

certbot certonly \
  --webroot \
  -w /var/www/certbot \
  --non-interactive \
  --agree-tos \
  --email admin@onwuachi.com \
  -d onwuachi.com \
  -d www.onwuachi.com

echo "Building HAProxy PEM..."
/etc/letsencrypt/renewal-hooks/deploy/haproxy


systemctl reload haproxy
systemctl enable cert-bootstrap.service