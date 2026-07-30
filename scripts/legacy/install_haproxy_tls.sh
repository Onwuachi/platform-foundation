#!/bin/bash
set -e

DOMAIN="onwuachi.com"
EMAIL="admin@$DOMAIN"
CERT_DIR="/etc/haproxy/certs"
PEM_PATH="$CERT_DIR/site.pem"

echo "📦 Installing Certbot..."
apt update -y
apt install -y snapd curl
snap install core; snap refresh core     
snap install --classic certbot
ln -sf /snap/bin/certbot /usr/bin/certbot

echo "🌐 Checking DNS..."
PUBLIC_IP=$(curl -s ifconfig.me)
DNS_IP=$(dig +short $DOMAIN | head -n1)

echo "Public IP: $PUBLIC_IP"
echo "DNS IP:    $DNS_IP"

if [ "$PUBLIC_IP" != "$DNS_IP" ]; then
  echo "❌ DNS does not point to this server"
  exit 1
fi

echo "🛑 Stopping HAProxy for standalone certbot..."
systemctl stop haproxy || true

echo "🔐 Requesting cert..."
certbot certonly --standalone \
  -d $DOMAIN -d www.$DOMAIN \
  --agree-tos \
  --email $EMAIL \
  --non-interactive

echo "📁 Creating HAProxy cert directory..."
mkdir -p $CERT_DIR
chmod 700 $CERT_DIR

echo "🔗 Combining cert for HAProxy..."
cat /etc/letsencrypt/live/$DOMAIN/fullchain.pem \
    /etc/letsencrypt/live/$DOMAIN/privkey.pem \
    > $PEM_PATH

chmod 600 $PEM_PATH
chown root:root $PEM_PATH

echo "🔍 Validating HAProxy config..."
haproxy -c -f /etc/haproxy/haproxy.cfg

echo "🚀 Starting HAProxy..."
systemctl start haproxy

echo "♻️ Auto-renew hook..."
cat >/etc/cron.d/certbot-haproxy <<EOF
0 3 * * * root certbot renew --quiet \
  && cat /etc/letsencrypt/live/$DOMAIN/fullchain.pem \
         /etc/letsencrypt/live/$DOMAIN/privkey.pem \
         > $PEM_PATH \
  && systemctl reload haproxy
EOF

echo "✅ HTTPS ready: https://$DOMAIN"