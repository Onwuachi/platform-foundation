#!/usr/bin/env bash
set -euo pipefail

exec > >(tee -a /var/log/platform-rehydrate.log) 2>&1

echo "=== Rehydrating platform ==="

DOMAIN="onwuachi.com"
CERT_BASE="/opt/platform/certs"
WEBROOT="/var/www/certbot"
SERVICES_DIR="/opt/platform/services"

########################################
# SYNC STATE
########################################

mkdir -p "$SERVICES_DIR"
aws s3 sync s3://platform-api-services/platform/services "$SERVICES_DIR"

########################################
# CERT SETUP
########################################

mkdir -p "$CERT_BASE"
mkdir -p "$WEBROOT"

if [ ! -L /etc/letsencrypt ]; then
  rm -rf /etc/letsencrypt
  ln -s "$CERT_BASE" /etc/letsencrypt
fi

########################################
# TEMP WEB SERVER (SAFE)
########################################

cd "$WEBROOT"

if ! lsof -i :8089 >/dev/null 2>&1; then
  python3 -m http.server 8089 >/dev/null 2>&1 &
  PID=$!
  sleep 2
else
  PID=""
fi

########################################
# ISSUE CERT (ONCE)
########################################

if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
  certbot certonly \
    --webroot \
    -w "$WEBROOT" \
    --non-interactive \
    --agree-tos \
    --email admin@$DOMAIN \
    -d $DOMAIN \
    -d www.$DOMAIN || true
fi

########################################
# BUILD PEM
########################################

mkdir -p /etc/haproxy/certs

if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
  cat \
    /etc/letsencrypt/live/$DOMAIN/fullchain.pem \
    /etc/letsencrypt/live/$DOMAIN/privkey.pem \
    > /etc/haproxy/certs/$DOMAIN.pem

  chmod 600 /etc/haproxy/certs/$DOMAIN.pem
fi

[ -n "${PID:-}" ] && kill $PID || true

########################################
# RENDER CONFIGS
########################################

mkdir -p /etc/haproxy/services

if [ -x /usr/local/bin/platform-render-haproxy.sh ]; then
  /usr/local/bin/platform-render-haproxy.sh
else
  echo "❌ Missing renderer"
  exit 1
fi

########################################
# VALIDATE + RELOAD
########################################

haproxy -c -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/services/ || exit 1
systemctl reload haproxy

echo "=== Rehydrate complete ==="