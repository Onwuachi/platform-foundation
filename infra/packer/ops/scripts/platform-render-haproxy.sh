#!/usr/bin/env bash
set -euo pipefail

SERVICES_DIR="/opt/platform/services"
HAPROXY_DIR="/etc/haproxy"
OUTPUT_DIR="${HAPROXY_DIR}/services"
MAP_FILE="${HAPROXY_DIR}/domain.map"

echo "Waiting for Docker..."

for i in {1..10}; do
  if systemctl is-active docker >/dev/null 2>&1; then
    echo "Docker ready"
    break
  fi
  sleep 3
done

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DIR"/*.cfg

if [ ! -f "$SERVICES_DIR/services.list" ]; then
  echo "⚠️ No services defined — leaving domain.map untouched"
  exit 0
fi

# Build fresh domain map safely
TMP_MAP=$(mktemp)
> "$TMP_MAP"

while read -r SERVICE; do
  [ -z "$SERVICE" ] && continue

  PORT_FILE="$SERVICES_DIR/${SERVICE}.port"
  DOMAIN_FILE="$SERVICES_DIR/${SERVICE}.domain"

  if [ ! -f "$PORT_FILE" ]; then
    echo "⚠️ Missing port for $SERVICE — skipping"
    continue
  fi

  PORT=$(cat "$PORT_FILE")

  if [ -f "$DOMAIN_FILE" ]; then
    DOMAIN=$(cat "$DOMAIN_FILE")
  else
    DOMAIN="${SERVICE}.onwuachi.com"
  fi

  ########################################
  # CREATE BACKEND FILE
  ########################################

  if [ "$SERVICE" = "hugo" ]; then
  cat > "$OUTPUT_DIR/${SERVICE}.cfg" <<EOF
backend ${SERVICE}_backend
  http-request set-path %[path,regsub(^/hugo,)]
  server ${SERVICE} 127.0.0.1:${PORT}
EOF
else
  cat > "$OUTPUT_DIR/${SERVICE}.cfg" <<EOF
backend ${SERVICE}_backend
  server ${SERVICE} 127.0.0.1:${PORT}
EOF
fi

  ########################################
  # ADD TO MAP (SAFE)
  ########################################

  #printf "%s %s\n" "$DOMAIN" "${SERVICE}_backend" >> "$TMP_MAP"

########################################
# ADD TO MAP (MULTI-DOMAIN SAFE)
########################################

IFS=',' read -ra DOMAINS <<< "$DOMAIN"

for d in "${DOMAINS[@]}"; do
  printf "%s %s\n" "$d" "${SERVICE}_backend" >> "$TMP_MAP"
done
done < "$SERVICES_DIR/services.list"

########################################
# VALIDATE MAP
########################################

if [ ! -s "$TMP_MAP" ]; then
  echo "❌ Generated empty domain map — aborting"
  exit 1
fi

########################################
# REMOVE DUPES (ORDER SAFE)
########################################

awk '!seen[$0]++' "$TMP_MAP" > "${TMP_MAP}.dedup"
mv "${TMP_MAP}.dedup" "$TMP_MAP"

########################################
# ATOMIC REPLACE
########################################

mv "$TMP_MAP" "$MAP_FILE"


echo "=== Render complete ==="
cat "$MAP_FILE"


echo "=== AFTER RENDER ==="
ls -l /etc/haproxy/
cat /etc/haproxy/domain.map || true
