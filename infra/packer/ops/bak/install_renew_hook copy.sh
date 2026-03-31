#!/usr/bin/env bash
set -e

mkdir -p /etc/letsencrypt/renewal-hooks/deploy

cat >/etc/letsencrypt/renewal-hooks/deploy/haproxy <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

DOMAIN="onwuachi.com"
LIVE="/etc/letsencrypt/live/$DOMAIN"
DEST="/etc/haproxy/certs/$DOMAIN.pem"

if [ -f "$LIVE/fullchain.pem" ]; then
  cat "$LIVE/fullchain.pem" "$LIVE/privkey.pem" > "$DEST"
  chmod 600 "$DEST"
  systemctl reload haproxy
fi
EOF

chmod 755 /etc/letsencrypt/renewal-hooks/deploy/haproxy
