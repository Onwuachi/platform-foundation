#!/usr/bin/env bash
set -e

echo "=== Rehydrating platform ==="

DOMAIN="onwuachi.com"
CERT_BASE="/opt/platform/certs"
WEBROOT="/var/www/certbot"

########################################
# Ensure cert storage + symlink
########################################

mkdir -p "$CERT_BASE"

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

if [ ! -f "$CERT_BASE/live/$DOMAIN/fullchain.pem" ]; then
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

if [ -f /opt/platform/services.list ]; then
  while read -r svc; do
    [ -z "$svc" ] && continue

    PORT_FILE="/opt/platform/${svc}.port"

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

systemctl reload haproxy || true

########################################
# Restart platform services
########################################

if [ -f /opt/platform/services.list ]; then
  while read service; do
    systemctl restart platform-$service || true
  done < /opt/platform/services.list
fi

echo "=== Rehydrate complete ==="