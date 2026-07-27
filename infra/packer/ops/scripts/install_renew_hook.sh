#!/usr/bin/env bash
set -euo pipefail

#
# Certbot deploy hook
#
# Called automatically after a successful renewal.
#

PRIMARY_DOMAIN="${RENEWED_DOMAINS%% *}"

DEST="/etc/haproxy/certs/${PRIMARY_DOMAIN}.pem"

cat \
  "$RENEWED_LINEAGE/fullchain.pem" \
  "$RENEWED_LINEAGE/privkey.pem" \
  > "$DEST"

chmod 600 "$DEST"

echo "Updated HAProxy certificate: $DEST"

systemctl reload haproxy
