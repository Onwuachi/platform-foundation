#!/bin/bash

DOMAIN="onwua.com"
EMAIL="admin@$DOMAIN"
PEM_PATH="/etc/letsencrypt/live/$DOMAIN/haproxy.pem"

echo "📦 Installing Certbot via Snap..."
sudo apt update -y
sudo apt install snapd -y
sudo snap install core; sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

echo "🌐 Verifying public IP and DNS..."
PUBLIC_IP=$(curl -s ifconfig.me)
DNS_IP=$(dig +short $DOMAIN)

echo "🔍 Public IP: $PUBLIC_IP"
echo "🔍 DNS A record: $DNS_IP"

if [ "$PUBLIC_IP" != "$DNS_IP" ]; then
  echo "❌ DNS does not point to this server. Update DNS and retry."
  exit 1
fi

echo "🛑 Stopping Nginx and HAProxy to free up port 80..."
sudo systemctl stop nginx || true
sudo systemctl stop haproxy || true

echo "🔐 Requesting SSL certificate for $DOMAIN..."
sudo certbot certonly --standalone \
  -d $DOMAIN -d www.$DOMAIN \
  --agree-tos -m $EMAIL \
  --non-interactive

echo "🔗 Combining cert and key for HAProxy..."
sudo bash -c "cat /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/letsencrypt/live/$DOMAIN/privkey.pem > $PEM_PATH"
sudo chmod 600 $PEM_PATH

# ✅ Ensure PEM file exists before validating HAProxy
if [ ! -f "$PEM_PATH" ]; then
  echo "❌ HAProxy PEM file not found at $PEM_PATH — check permissions or run script as root."
  exit 1
fi

# 🔧 Patch HAProxy config if missing
if ! grep -q "bind \*:443 ssl crt $PEM_PATH" /etc/haproxy/haproxy.cfg; then
  echo "🔧 Updating HAProxy config..."
  sudo tee -a /etc/haproxy/haproxy.cfg > /dev/null <<EOF

frontend https_in
    bind *:443 ssl crt $PEM_PATH
    mode http
    default_backend web_backend

backend web_backend
    server web1 127.0.0.1:8080 check
EOF
fi

# 🔧 Reconfigure Nginx to listen on port 8080
echo "🔧 Reconfiguring Nginx to listen on port 8080..."
sudo sed -i 's/listen 80 default_server;/listen 8080 default_server;/g' /etc/nginx/sites-available/default
sudo sed -i 's/listen \[::\]:80 default_server;/listen [::]:8080 default_server;/g' /etc/nginx/sites-available/default

echo "🛠 Validating HAProxy config..."
sudo haproxy -f /etc/haproxy/haproxy.cfg -c

echo "🚀 Restarting HAProxy and Nginx..."
sudo systemctl start haproxy
sudo systemctl start nginx

# 📝 Replace default Nginx page with custom welcome message
echo "📝 Customizing Nginx welcome page..."
if [ -f /var/www/html/index.nginx-debian.html ]; then
  sudo mv /var/www/html/index.nginx-debian.html /var/www/html/index.nginx-debian.html-bak
fi

echo '<h1>Welcome to Onwua.com</h1><p>DevOps KB & Links Coming Soon. CloudOpsNinja lives here.</p>' | sudo tee /var/www/html/index.html > /dev/null

echo "🔁 Setting up auto-renewal..."
(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet && cat /etc/letsencrypt/live/$DOMAIN/fullchain.pem /etc/letsencrypt/live/$DOMAIN/privkey.pem > $PEM_PATH && systemctl reload haproxy") | sudo crontab -

echo "✅ SSL setup complete. Test with: curl -I https://$DOMAIN"