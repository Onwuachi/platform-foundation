sudo tee /usr/local/bin/bootstrap-cert.sh <<'EOF'
#!/usr/bin/env bash
set -e

DOMAIN="onwuachi.com"
EMAIL="you@example.com"

if [ ! -d "/etc/letsencrypt/live/$DOMAIN" ]; then
  echo "Issuing initial certificate..."

  certbot certonly \
    --webroot \
    -w /var/www/certbot \
    -d $DOMAIN \
    --email $EMAIL \
    --agree-tos \
    --non-interactive

  echo "Building HAProxy PEM..."
  /etc/letsencrypt/renewal-hooks/deploy/haproxy
else
  echo "Certificate already exists, skipping."
fi
EOF