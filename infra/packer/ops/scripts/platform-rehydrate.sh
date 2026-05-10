#!/usr/bin/env bash
set -euo pipefail

########################################
# LOGGING
########################################

LOG_FILE="/var/log/platform-rehydrate.log"

touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Rehydrating Platform ==="

########################################
# CONFIG
########################################

DOMAIN="onwuachi.com"

CERT_BASE="/opt/platform/certs"
WEBROOT="/var/www/certbot"

SERVICES_DIR="/opt/platform/services"

HAPROXY_CERT_DIR="/etc/haproxy/certs"

S3_BUCKET="s3://platform-api-services"

########################################
# PREP DIRECTORIES
########################################

mkdir -p "$SERVICES_DIR"
mkdir -p "$CERT_BASE"
mkdir -p "$WEBROOT"
mkdir -p "$HAPROXY_CERT_DIR"
mkdir -p /etc/haproxy/services

########################################
# SYNC PLATFORM STATE
########################################

echo "=== Syncing platform services from S3 ==="

aws s3 sync \
  "${S3_BUCKET}/platform/services" \
  "$SERVICES_DIR" \
  --delete
########################################
# DEBUG
########################################

echo
echo "=== SERVICES ==="

ls -l "$SERVICES_DIR"

########################################
# LETSENCRYPT PERSISTENCE
########################################

echo
echo "=== Configuring certificate persistence ==="

if [ ! -L /etc/letsencrypt ]; then
  rm -rf /etc/letsencrypt
  ln -s "$CERT_BASE" /etc/letsencrypt
fi

########################################
# TEMP CERTBOT WEB SERVER
########################################

echo
echo "=== Starting temporary certbot webserver ==="

cd "$WEBROOT"

CERTBOT_PID=""

if ! lsof -i :8089 >/dev/null 2>&1; then
  python3 -m http.server 8089 >/dev/null 2>&1 &
  CERTBOT_PID=$!

  sleep 2
fi

########################################
# CERTIFICATE RENEWAL
########################################

echo
echo "=== Attempting certificate renewal ==="

if certbot renew --quiet; then
  echo "Certificate renewal completed"
else
  echo "Certificate renewal encountered issues (continuing)"
fi

########################################
# CERTIFICATE VALIDATION
########################################

FULLCHAIN="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
PRIVKEY="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"

VALID_CERT=false

echo
echo "=== Validating certificate ==="

if [ -f "$FULLCHAIN" ]; then
  if openssl x509 -in "$FULLCHAIN" -noout >/dev/null 2>&1; then
    VALID_CERT=true

    echo "Valid certificate found"
  fi
fi

########################################
# REQUEST CERT IF MISSING
########################################

if [ "$VALID_CERT" = false ]; then

  echo
  echo "=== Requesting new certificate ==="

  certbot certonly \
    --webroot \
    -w "$WEBROOT" \
    --non-interactive \
    --agree-tos \
    --email "admin@${DOMAIN}" \
    -d "${DOMAIN}" \
    -d "www.${DOMAIN}" || true
fi

########################################
# FINAL CERT VALIDATION
########################################

echo
echo "=== Performing final certificate validation ==="

if [ ! -f "$FULLCHAIN" ]; then
  echo "❌ Missing fullchain.pem"

  exit 1
fi

if [ ! -f "$PRIVKEY" ]; then
  echo "❌ Missing privkey.pem"

  exit 1
fi

########################################
# BUILD HAPROXY PEM
########################################

echo
echo "=== Building HAProxy PEM ==="

cat \
  "$FULLCHAIN" \
  "$PRIVKEY" \
  > "${HAPROXY_CERT_DIR}/${DOMAIN}.pem"

chmod 600 "${HAPROXY_CERT_DIR}/${DOMAIN}.pem"

########################################
# REMOVE NON-PEM FILES
########################################

find "$HAPROXY_CERT_DIR" \
  -type f \
  ! -name "*.pem" \
  -delete

########################################
# STOP TEMP SERVER
########################################

echo
echo "=== Cleaning up temporary services ==="

if [ -n "$CERTBOT_PID" ]; then
  kill "$CERTBOT_PID" || true
fi

########################################
# RENDER HAPROXY CONFIGS
########################################

echo
echo "=== Rendering HAProxy configs ==="

if [ ! -x /usr/local/bin/platform-render-haproxy.sh ]; then
  echo "❌ Missing platform-render-haproxy.sh"

  exit 1
fi

/usr/local/bin/platform-render-haproxy.sh

########################################
# VALIDATE HAPROXY
########################################

echo
echo "=== Validating HAProxy configuration ==="

haproxy -c \
  -f /etc/haproxy/haproxy.cfg \
  -f /etc/haproxy/services/ || exit 1

########################################
# START PLATFORM SERVICES
########################################

echo
echo "=== Starting platform services ==="

FAILED_SERVICES=()

if [ ! -f "${SERVICES_DIR}/services.list" ]; then
  echo "❌ Missing services.list"

  exit 1
fi

while read -r SERVICE; do

  [ -z "$SERVICE" ] && continue

  echo
  echo "--- Processing service: ${SERVICE} ---"

  PORT_FILE="${SERVICES_DIR}/${SERVICE}.port"

  if [ ! -f "$PORT_FILE" ]; then
    echo "⚠️ Missing port definition for ${SERVICE}"

    FAILED_SERVICES+=("$SERVICE")

    continue
  fi

  PORT=$(cat "$PORT_FILE")

  IMAGE="046685909731.dkr.ecr.us-east-1.amazonaws.com/${SERVICE}:latest"

  ########################################
  # PULL IMAGE
  ########################################

  if ! docker pull "$IMAGE"; then
    echo "❌ Failed to pull ${IMAGE}"

    FAILED_SERVICES+=("$SERVICE")

    continue
  fi

  ########################################
  # SYSTEMD UNIT
  ########################################

  SERVICE_FILE="/etc/systemd/system/platform-${SERVICE}.service"

cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Platform Service - ${SERVICE}

After=docker.service
Requires=docker.service

[Service]
Restart=always
RestartSec=5

ExecStartPre=-/usr/bin/docker rm -f ${SERVICE}

ExecStart=/usr/bin/docker run \
  --name ${SERVICE} \
  -p 127.0.0.1:${PORT}:80 \
  ${IMAGE}

ExecStop=/usr/bin/docker stop ${SERVICE}

[Install]
WantedBy=multi-user.target
EOF

  ########################################
  # START SERVICE
  ########################################

  systemctl daemon-reload

  systemctl enable "platform-${SERVICE}"

  if ! systemctl restart "platform-${SERVICE}"; then
    echo "❌ Failed to start ${SERVICE}"

    FAILED_SERVICES+=("$SERVICE")

    continue
  fi

done < "${SERVICES_DIR}/services.list"

########################################
# FINAL HAPROXY VALIDATION
########################################

echo
echo "=== Final HAProxy validation ==="

haproxy -c \
  -f /etc/haproxy/haproxy.cfg \
  -f /etc/haproxy/services/ || exit 1

########################################
# RELOAD/RSTART HAPROXY
########################################

echo
echo "=== Activating HAProxy ==="

if systemctl is-active --quiet haproxy; then
  systemctl reload haproxy
else
  systemctl restart haproxy
fi

sleep 2

if ! systemctl is-active --quiet haproxy; then
  echo "❌ HAProxy failed to start"
  journalctl -u haproxy -n 50 --no-pager
  exit 1
fi

########################################
# FINAL STATUS
########################################

echo
echo "=== Rehydrate Complete ==="

if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
  echo
  echo "⚠️ Some services failed:"

  printf ' - %s\n' "${FAILED_SERVICES[@]}"

  exit 1
fi

echo "All services started successfully"
