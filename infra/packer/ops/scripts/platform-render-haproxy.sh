#!/usr/bin/env bash
set -euo pipefail

SERVICES_DIR="/opt/platform/services"
HAPROXY_DIR="/etc/haproxy"
BACKEND_DIR="$HAPROXY_DIR/services"
MAP_FILE="$HAPROXY_DIR/domain.map"

mkdir -p "$BACKEND_DIR"
rm -f "$BACKEND_DIR"/*.cfg
: > "$MAP_FILE"

if [ ! -f "$SERVICES_DIR/services.list" ]; then
  echo "No services defined"
  exit 0
fi

while read -r SERVICE; do
  [ -z "$SERVICE" ] && continue

  PORT_FILE="$SERVICES_DIR/${SERVICE}.port"
  DOMAIN_FILE="$SERVICES_DIR/${SERVICE}.domain"

  [ -f "$PORT_FILE" ] || continue

  PORT=$(cat "$PORT_FILE")

  if [ -f "$DOMAIN_FILE" ]; then
    DOMAIN=$(cat "$DOMAIN_FILE")
  else
    DOMAIN="${SERVICE}.onwuachi.com"
  fi

  ########################################
  # WRITE BACKEND ONLY
  ########################################

  cat > "$BACKEND_DIR/${SERVICE}.cfg" <<EOF
backend ${SERVICE}_backend
  server ${SERVICE} 127.0.0.1:${PORT}
EOF

  ########################################
  # WRITE DOMAIN MAP
  ########################################

  echo "${DOMAIN} ${SERVICE}_backend" >> "$MAP_FILE"

done < "$SERVICES_DIR/services.list"

echo "HAProxy configs rendered:"
ls -l "$BACKEND_DIR"
echo "Domain map:"
cat "$MAP_FILE"
