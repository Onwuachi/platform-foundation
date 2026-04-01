#!/usr/bin/env bash
set -euo pipefail

echo "=== Rehydrating platform ==="

########################################
# LETSENCRYPT RATE LIMIT GUARD
########################################

if grep -Eqi "too many certificates|rate limit|429" /var/log/letsencrypt/letsencrypt.log 2>/dev/null; then
  echo "⚠️ Rate limited — skipping cert request"
  SKIP_CERTBOT=true
fi

DOMAIN="onwuachi.com"
CERT_BASE="/opt/platform/certs"
WEBROOT="/var/www/certbot"

########################################
# Ensure cert storage + symlink
########################################

mkdir -p "$CERT_BASE"

########################################
# SAFETY: prevent recursive platform corruption
########################################

if find /opt/platform -type d -path "*platform/services/platform*" | grep -q .; then
  echo "❌ Recursive platform structure detected. Aborting."
  exit 1
fi

if [ ! -L /etc/letsencrypt ]; then
  rm -rf /etc/letsencrypt
  ln -s "$CERT_BASE" /etc/letsencrypt
fi

mkdir -p "$WEBROOT"

########################################
# Start temporary ACME webroot server
########################################

echo "Starting temporary ACME webroot server..."

cd "$WEBROOT"
python3 -m http.server 8089 >/var/log/certbot-webroot.log 2>&1 &
WEBROOT_PID=$!

sleep 3

########################################
# Issue cert if missing
########################################

if [ "$SKIP_CERTBOT" = false ] && [ ! -f "$CERT_BASE/live/$DOMAIN/fullchain.pem" ]; then
  echo "No cert found — requesting new one..."

  certbot certonly \
    --webroot \
    -w "$WEBROOT" \
    --non-interactive \
    --agree-tos \
    --email admin@$DOMAIN \
    -d $DOMAIN \
    -d www.$DOMAIN

else
  echo "Cert already exists — skipping issuance"
fi

########################################
# Build HAProxy PEM (ALWAYS)
########################################

if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
  cat \
    /etc/letsencrypt/live/$DOMAIN/fullchain.pem \
    /etc/letsencrypt/live/$DOMAIN/privkey.pem \
    > /etc/haproxy/certs/$DOMAIN.pem

  chmod 600 /etc/haproxy/certs/$DOMAIN.pem
fi

########################################
# Stop temporary server
########################################

echo "Stopping webroot server..."
kill $WEBROOT_PID || true

########################################
# Rebuild HAProxy dynamic configs
########################################

echo "Rebuilding HAProxy configs..."

rm -f /etc/haproxy/services/*.cfg || true
mkdir -p /etc/haproxy/services

if [ -f /opt/platform/services/services.list ]; then
  while read -r svc; do
    [ -z "$svc" ] && continue

    PORT_FILE="/opt/platform/services/${svc}.port"

    if [ -f "$PORT_FILE" ]; then
      PORT=$(cat "$PORT_FILE")

      cat > "/etc/haproxy/services/${svc}.cfg" <<EOF
backend ${svc}_backend
  http-request replace-path ^/${svc}/?(.*)$ /\1
  server ${svc}1 127.0.0.1:${PORT} check
EOF

      echo "Rebuilt $svc → $PORT"
    fi
  done < /opt/platform/services.list
fi

########################################
# Reload HAProxy (ZERO downtime)
########################################

haproxy -c -f /etc/haproxy/haproxy.cfg || exit 1
systemctl reload haproxy

########################################
# Restart platform services
########################################

if [ -f /opt/platform/services.list ]; then
  while read service; do
    systemctl restart platform-$service || true
  done < /opt/platform/services.list
fi

echo "=== Rehydrate complete ==="