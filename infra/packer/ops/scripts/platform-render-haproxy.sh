#!/usr/bin/env bash
set -euo pipefail

SERVICES_DIR="/opt/platform/services"
HAPROXY_DIR="/etc/haproxy"
OUTPUT_DIR="${HAPROXY_DIR}/services"
MAP_FILE="${HAPROXY_DIR}/domain.map"


mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.cfg

if [ ! -f "$SERVICES_DIR/services.list" ]; then
  echo "⚠️ No services defined — leaving domain.map untouched"
  exit 0
fi

# ONLY clear map if we are about to rebuild it
> "$MAP_FILE"



while read -r SERVICE; do
  [ -z "$SERVICE" ] && continue

  PORT_FILE="$SERVICES_DIR/${SERVICE}.port"
  DOMAIN_FILE="$SERVICES_DIR/${SERVICE}.domain"

  [ -f "$PORT_FILE" ] || continue

  PORT=$(cat "$PORT_FILE")

  # Default domain if not defined
  if [ -f "$DOMAIN_FILE" ]; then
    DOMAIN=$(cat "$DOMAIN_FILE")
  else
    DOMAIN="${SERVICE}.onwuachi.com"
  fi

  ########################################
  # CREATE BACKEND FILE
  ########################################

  cat > "$OUTPUT_DIR/${SERVICE}.cfg" <<EOF
backend ${SERVICE}_backend
  server ${SERVICE} 127.0.0.1:${PORT}
EOF

  ########################################
  # ADD TO DOMAIN MAP
  ########################################

  echo "${DOMAIN} ${SERVICE}_backend" >> "$MAP_FILE"

done < "$SERVICES_DIR/services.list"

echo "=== Render complete ==="
cat "$MAP_FILE"


echo "=== AFTER RENDER ==="
ls -l /etc/haproxy/
cat /etc/haproxy/domain.map || true
