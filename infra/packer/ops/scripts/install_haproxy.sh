#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "=== Installing HAProxy (AMI-safe) ==="

apt-get update
apt-get install -y software-properties-common

add-apt-repository -y ppa:vbernat/haproxy-2.8

apt-get update

apt-get install -y haproxy certbot python3


mkdir -p /etc/haproxy
mkdir -p /etc/haproxy/certs
mkdir -p /etc/haproxy/services
# placeholder
touch /etc/haproxy/services/_placeholder.cfg

# Placeholder domain map so HAProxy validation passes during AMI build
echo "default_backend default_backend" > /etc/haproxy/domain.map

# Create systemd override to include dynamic service configs
mkdir -p /etc/systemd/system/haproxy.service.d

cat <<'EOF' >/etc/systemd/system/haproxy.service.d/override.conf

[Service]
ExecStart=
ExecStart=/usr/sbin/haproxy -Ws \
  -f /etc/haproxy/haproxy.cfg \
  -f /etc/haproxy/services/

EOF

# ------------------------------------------------------------
# Write HAProxy config (HAProxy 2.8 with dynamic service includes)
# ------------------------------------------------------------
cat <<'EOF' >/etc/haproxy/haproxy.cfg
global
  daemon
  maxconn 2048
  log /dev/log local0 info
  stats socket /run/haproxy/admin.sock mode 660 level admin

defaults
  mode http
  log global
  option httplog
  timeout connect 5s
  timeout client 50s
  timeout server 50s

########################################
# HTTP (80)
########################################

frontend http_in
  bind *:80

  # ACME challenge
  acl acme_challenge path_beg /.well-known/acme-challenge/
  use_backend certbot_backend if acme_challenge

  # Redirect everything else
  http-request redirect scheme https code 301 unless acme_challenge
  # Redirect everything else
  http-request redirect scheme https code 301 unless acme_challenge
  http-request redirect scheme https code 301 unless acme_challenge

########################################
# HTTPS (443)
########################################

frontend https_in
  bind *:443 ssl crt /etc/haproxy/certs/onwuachi.com.pem


  # 🔥 DOMAIN MAP (THE CORE)
  use_backend %[req.hdr(host),lower,map(/etc/haproxy/domain.map,default_backend)]

########################################
# DEFAULT BACKEND
########################################

backend default_backend
  http-request return status 503 content-type text/plain lf-string "Service not found"

########################################
# CERTBOT
########################################

backend certbot_backend
  server certbot 127.0.0.1:8089
EOF

# ensure permissions
chmod 644 /etc/haproxy/haproxy.cfg

# debug visibility
echo "==== FINAL HAPROXY CONFIG ===="
cat /etc/haproxy/haproxy.cfg

# ------------------------------------------------------------
# Temporary self-signed cert (replaced by certbot at runtime)
# ------------------------------------------------------------
openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/haproxy/certs/onwuachi.com.key \
  -out /etc/haproxy/certs/onwuachi.com.crt \
  -subj "/CN=onwuachi.com"

cat /etc/haproxy/certs/onwuachi.com.crt \
    /etc/haproxy/certs/onwuachi.com.key \
    > /etc/haproxy/certs/onwuachi.com.pem

# ------------------------------------------------------------
# Validate configuration (critical for AMI builds)
# ------------------------------------------------------------
echo "==> Validating HAProxy config"
echo "default_backend default_backend" > /etc/haproxy/domain.map

haproxy -c -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/services/

# ------------------------------------------------------------
# Enable service but DO NOT start it in AMI build
# ------------------------------------------------------------
sudo systemctl daemon-reload
systemctl enable haproxy
systemctl stop haproxy || true

echo "=== HAProxy AMI provisioning complete ==="

