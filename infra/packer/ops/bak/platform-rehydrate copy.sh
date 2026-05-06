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
aws s3 sync "$CERT_BASE" s3://platform-api-services/platform/certs

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

echo "=== HAPROXY DOMAIN MAP ==="
cat /etc/haproxy/domain.map || true

########################################
# CERT SETUP
########################################

mkdir -p "$CERT_BASE"
mkdir -p "$WEBROOT"

# Ensure certbot directory is symlinked to persistent storage
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
# ISSUE CERT (ONCE, WITH REAL FEEDBACK)
########################################

CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"

if [ ! -f "$CERT_PATH" ]; then
  echo "Requesting cert..."

  if certbot certonly \
    --webroot \
    -w "$WEBROOT" \
    --non-interactive \
    --agree-tos \
    --email admin@$DOMAIN \
    -d $DOMAIN \
    -d www.$DOMAIN; then

    echo "✅ Certbot succeeded"

  else
    echo "❌ Certbot failed — will fall back to self-signed cert"
  fi
else
  echo "Cert already exists, skipping issuance"
fi


########################################
# BUILD PEM FOR HAPROXY (REAL OR FALLBACK)
########################################

HAPROXY_PEM="/etc/haproxy/certs/$DOMAIN.pem"

if [ -f "$CERT_PATH" ]; then
  echo "Using real Let's Encrypt cert"

  cat \
    /etc/letsencrypt/live/$DOMAIN/fullchain.pem \
    /etc/letsencrypt/live/$DOMAIN/privkey.pem \
    > "$HAPROXY_PEM"

  chmod 600 "$HAPROXY_PEM"

else
  echo "⚠️ Using fallback self-signed cert"

  openssl req -x509 -nodes -days 30 \
    -newkey rsa:2048 \
    -keyout /etc/haproxy/certs/$DOMAIN.key \
    -out /etc/haproxy/certs/$DOMAIN.crt \
    -subj "/CN=$DOMAIN"

  cat \
    /etc/haproxy/certs/$DOMAIN.crt \
    /etc/haproxy/certs/$DOMAIN.key \
    > "$HAPROXY_PEM"

  chmod 600 "$HAPROXY_PEM"
fi


########################################
# 🔥 CRITICAL: RELOAD HAPROXY AFTER CERT UPDATE
########################################

echo "Reloading HAProxy to apply certificate..."

if systemctl is-active --quiet haproxy; then
  systemctl reload haproxy
  echo "✅ HAProxy reloaded"
else
  echo "⚠️ HAProxy not running yet"
fi


########################################
# Kill temporary ACME server
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
# AUTH TO ECR (🔥 REQUIRED)
########################################

#echo "Authenticating to ECR..."

#aws ecr get-login-password --region us-east-1 | \
#  docker login --username AWS --password-stdin 046685909731.dkr.ecr.us-east-1.amazonaws.com

########################################
# BUILD + START SERVICES
########################################

echo "Starting services..."

for SERVICE in $(cat "$SERVICES_DIR/services.list"); do
  echo "Processing service: $SERVICE"

  PORT=$(cat "$SERVICES_DIR/${SERVICE}.port")
  IMAGE="046685909731.dkr.ecr.us-east-1.amazonaws.com/${SERVICE}:latest"

  echo "Using port: $PORT"
  echo "Using image: $IMAGE"

  #echo "Authenticating to ECR..."
  #aws ecr get-login-password --region us-east-1 | \
  #  docker login --username AWS --password-stdin 046685909731.dkr.ecr.us-east-1.amazonaws.com

  echo "Pulling image..."
  docker pull "$IMAGE" || { echo "FAILED TO PULL $SERVICE"; exit 1; }

  SERVICE_FILE="/etc/systemd/system/platform-${SERVICE}.service"

  echo "Creating systemd service: $SERVICE_FILE"

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

  echo "Reloading systemd..."
  systemctl daemon-reexec
  systemctl daemon-reload

  echo "Enabling + restarting service..."
  systemctl enable platform-${SERVICE}
  systemctl restart platform-${SERVICE}

done

########################################
# VALIDATE + RELOAD HAPROXY
########################################

echo "Validating HAProxy..."

haproxy -c -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/services/ || exit 1

echo "Reloading HAProxy..."
systemctl reload haproxy

echo "=== Rehydrate complete ==="