#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/platform-rehydrate.log"
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Rehydrating platform ==="

DOMAIN="onwuachi.com"
CERT_BASE="/opt/platform/certs"
WEBROOT="/var/www/certbot"
SERVICES_DIR="/opt/platform/services"

########################################
# SYNC STATE FROM S3 (SOURCE OF TRUTH)
########################################

echo "Syncing services from S3..."
mkdir -p "$SERVICES_DIR"

aws s3 sync s3://platform-api-services/platform/services "$SERVICES_DIR"

########################################
# 🔥 SYNC CERTS FROM S3 (FIRST!)
########################################

echo "Syncing certs from S3..."
mkdir -p "$CERT_BASE"

aws s3 sync s3://platform-api-services/platform/certs "$CERT_BASE"

########################################
# DEBUG
########################################

echo "=== SERVICES AFTER SYNC ==="
ls -l "$SERVICES_DIR"
cat "$SERVICES_DIR/domain.map" || echo "No domain.map found"

########################################
# SYNC DOMAIN MAP → HAPROXY
########################################

echo "Syncing domain.map → /etc/haproxy..."

mkdir -p /etc/haproxy

if [ -f "$SERVICES_DIR/domain.map" ]; then
  cp "$SERVICES_DIR/domain.map" /etc/haproxy/domain.map
else
  echo "⚠️ No domain.map found, creating default"
  echo "default_backend default_backend" > /etc/haproxy/domain.map
fi

########################################
# CERT SETUP
########################################

mkdir -p "$CERT_BASE"
mkdir -p "$WEBROOT"

# Ensure persistence
if [ ! -L /etc/letsencrypt ]; then
  rm -rf /etc/letsencrypt
  ln -s "$CERT_BASE" /etc/letsencrypt
fi

########################################
# TEMP WEB SERVER FOR CERTBOT
########################################

cd "$WEBROOT"

if ! lsof -i :8089 >/dev/null 2>&1; then
  echo "Starting temporary webserver for certbot..."
  python3 -m http.server 8089 >/dev/null 2>&1 &
  PID=$!
  sleep 2
else
  PID=""
fi

########################################
# ISSUE / RENEW CERT
########################################

echo "Ensuring certificate is valid..."

if certbot renew --quiet; then
  echo "Certbot renew attempted"
else
  echo "Certbot renew had issues (continuing)"
fi

CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"

echo "Checking certificate validity..."

VALID_CERT=false

if [ -f "$CERT_PATH" ]; then
  if openssl x509 -in "$CERT_PATH" -noout >/dev/null 2>&1; then
    VALID_CERT=true
    echo "✅ Valid certificate found"
  else
    echo "⚠️ Invalid cert file"
  fi
else
  echo "⚠️ No cert found"
fi

########################################
# REQUEST CERT IF INVALID
########################################

if [ "$VALID_CERT" = false ]; then
  echo "Requesting new cert..."

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
# BUILD PEM FOR HAPROXY
########################################

#echo "Building HAProxy PEM..."

#CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"

#if [ ! -f "$CERT_PATH" ]; then
#  echo "❌ No valid cert found — aborting"
#  exit 1
#fi

#cat \
#  /etc/letsencrypt/live/$DOMAIN/fullchain.pem \
#  /etc/letsencrypt/live/$DOMAIN/privkey.pem \
#  > /etc/haproxy/certs/$DOMAIN.pem

#chmod 600 /etc/haproxy/certs/$DOMAIN.pem

CERT="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"

if [ ! -f "$CERT" ]; then
  echo "❌ Missing cert for $DOMAIN"
  exit 1
fi

cat $CERT /etc/letsencrypt/live/$DOMAIN/privkey.pem > /etc/haproxy/certs/$DOMAIN.pem
chmod 600 /etc/haproxy/certs/$DOMAIN.pem

########################################
# 🔥 SYNC CERTS BACK TO S3
########################################

echo "Syncing certs back to S3..."
aws s3 sync "$CERT_BASE" s3://platform-api-services/platform/certs

########################################
# CLEANUP
########################################

[ -n "${PID:-}" ] && kill $PID || true

########################################
# RENDER HAPROXY CONFIG
########################################

echo "Rendering HAProxy configs..."

mkdir -p /etc/haproxy/services

if [ -x /usr/local/bin/platform-render-haproxy.sh ]; then
  /usr/local/bin/platform-render-haproxy.sh
else
  echo "❌ Missing renderer"
  exit 1
fi

########################################
# START SERVICES
########################################

echo "Starting services..."

for SERVICE in $(cat "$SERVICES_DIR/services.list"); do
  echo "Processing service: $SERVICE"

  PORT=$(cat "$SERVICES_DIR/${SERVICE}.port")
  IMAGE="046685909731.dkr.ecr.us-east-1.amazonaws.com/${SERVICE}:latest"

  docker pull "$IMAGE" || { echo "FAILED TO PULL $SERVICE"; exit 1; }

  SERVICE_FILE="/etc/systemd/system/platform-${SERVICE}.service"

cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Platform Service - $SERVICE
After=docker.service
Requires=docker.service

[Service]
Restart=always
ExecStartPre=-/usr/bin/docker rm -f ${SERVICE}
ExecStart=/usr/bin/docker run \
  --name ${SERVICE} \
  -p 127.0.0.1:${PORT}:80 \
  ${IMAGE}
ExecStop=/usr/bin/docker stop ${SERVICE}

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl enable platform-${SERVICE}
  systemctl restart platform-${SERVICE}

done

########################################
# FINAL VALIDATION
########################################

echo "Validating HAProxy..."

haproxy -c -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/services/ || exit 1

echo "Reloading/Restarting HAProxy (final)..."
#systemctl reload haproxy
systemctl restart haproxy

echo "=== Rehydrate complete ==="
