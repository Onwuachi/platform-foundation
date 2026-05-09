#!/usr/bin/env bash
set -euo pipefail

SERVICES_DIR="/opt/platform/services"

HAPROXY_DIR="/etc/haproxy"
OUTPUT_DIR="${HAPROXY_DIR}/services"

MAP_FILE="${HAPROXY_DIR}/domain.map"

echo "=== Platform Rehydrate ==="

########################################
# WAIT FOR DOCKER
########################################

echo "Waiting for Docker..."

for i in {1..10}; do
  if systemctl is-active docker >/dev/null 2>&1; then
    echo "Docker ready"
    break
  fi

  sleep 3
done

########################################
# PREP OUTPUT
########################################

mkdir -p "$OUTPUT_DIR"

rm -f "$OUTPUT_DIR"/*.cfg

########################################
# VALIDATE SERVICES LIST
########################################

if [ ! -f "$SERVICES_DIR/services.list" ]; then
  echo "⚠️ No services defined"

  exit 0
fi

########################################
# BUILD DOMAIN MAP
########################################

TMP_MAP=$(mktemp)

> "$TMP_MAP"

########################################
# RENDER SERVICES
########################################

while read -r SERVICE; do

  [ -z "$SERVICE" ] && continue

  PORT_FILE="${SERVICES_DIR}/${SERVICE}.port"
  DOMAIN_FILE="${SERVICES_DIR}/${SERVICE}.domain"

  ########################################
  # VALIDATE PORT
  ########################################

  if [ ! -f "$PORT_FILE" ]; then
    echo "⚠️ Missing port for ${SERVICE} — skipping"

    continue
  fi

  PORT=$(cat "$PORT_FILE")

  ########################################
  # DOMAIN HANDLING
  ########################################

  if [ -f "$DOMAIN_FILE" ]; then
    DOMAIN=$(cat "$DOMAIN_FILE")
  else
    DOMAIN="${SERVICE}.onwuachi.com"
  fi

  ########################################
  # RENDER BACKEND
  ########################################

  cat > "${OUTPUT_DIR}/${SERVICE}.cfg" <<EOF
backend ${SERVICE}_backend
  server ${SERVICE} 127.0.0.1:${PORT}
EOF

  ########################################
  # SUPPORT MULTI-DOMAIN ENTRIES
  ########################################

  IFS=',' read -ra DOMAINS <<< "$DOMAIN"

  for d in "${DOMAINS[@]}"; do
    printf "%s %s\n" "$d" "${SERVICE}_backend" >> "$TMP_MAP"
  done

done < "$SERVICES_DIR/services.list"

########################################
# VALIDATE GENERATED MAP
########################################

if [ ! -s "$TMP_MAP" ]; then
  echo "❌ Generated empty domain map"

  exit 1
fi

########################################
# REMOVE DUPLICATES
########################################

awk '!seen[$0]++' "$TMP_MAP" > "${TMP_MAP}.dedup"

mv "${TMP_MAP}.dedup" "$TMP_MAP"

########################################
# ATOMIC REPLACE
########################################

mv "$TMP_MAP" "$MAP_FILE"

########################################
# OUTPUT
########################################

echo "=== Render Complete ==="

echo
echo "--- domain.map ---"

cat "$MAP_FILE"

echo
echo "--- services/ ---"

ls -l "$OUTPUT_DIR"
