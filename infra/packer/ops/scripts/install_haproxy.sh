#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=== Installing HAProxy (Phase 4.2 Baseline) ==="

# ------------------------------------------------------------
# Base packages
# ------------------------------------------------------------
apt-get update

apt-get install -y \
  software-properties-common \
  rsyslog \
  curl \
  haproxy \
  certbot \
  python3 \
  openssl \
  dos2unix

# ------------------------------------------------------------
# Directory structure
# ------------------------------------------------------------
mkdir -p /etc/haproxy/certs
mkdir -p /etc/haproxy/services

# Ensure include directory always exists
touch /etc/haproxy/services/_placeholder.cfg

# ------------------------------------------------------------
# Domain map (safe bootstrap default)
# ------------------------------------------------------------
echo "default_backend default_backend" > /etc/haproxy/domain.map

dos2unix /etc/haproxy/domain.map || true

# ------------------------------------------------------------
# HAProxy configuration
# ------------------------------------------------------------
cat <<'EOF' >/etc/haproxy/haproxy.cfg

########################################
# GLOBAL
########################################
global
  daemon

  maxconn 2048

  log /dev/log local0 info

  stats socket /run/haproxy/admin.sock mode 660 level admin

########################################
# DEFAULTS
########################################
defaults
  mode http

  log global

  option httplog

  timeout connect 5s
  timeout client 15s
  timeout server 15s
  timeout http-request 10s
  timeout http-keep-alive 5s

########################################
# HTTP (80)
########################################
frontend http_in
  bind *:80

  # ACME challenge support
  acl acme_challenge path_beg /.well-known/acme-challenge/

  # Redirect all other traffic to HTTPS
  http-request redirect scheme https code 301 unless acme_challenge

  use_backend certbot_backend if acme_challenge

########################################
# HTTPS (443)
########################################
frontend https_in
  bind *:443 ssl crt /etc/haproxy/certs/

  # Basic abuse protection
  maxconn 500

  stick-table type ip size 100k expire 30s store http_req_rate(10s)

  http-request track-sc0 src

  http-request deny deny_status 429 if { sc_http_req_rate(0) gt 100 }

  # Domain-based routing
  use_backend %[req.hdr(host),lower,field(1,:),map(/etc/haproxy/domain.map,default_backend)]

########################################
# BACKENDS
########################################

# Default fallback backend
backend default_backend
  http-request return status 503 content-type text/plain lf-string "Service not found"

# Certbot ACME challenge handler
backend certbot_backend
  server certbot 127.0.0.1:8089

EOF

chmod 644 /etc/haproxy/haproxy.cfg

# ------------------------------------------------------------
# Temporary self-signed cert (AMI bootstrap only)
# ------------------------------------------------------------
echo "==> Creating temporary bootstrap certificate"

rm -f /etc/haproxy/certs/*

openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/haproxy/certs/temp.key \
  -out /etc/haproxy/certs/temp.crt \
  -subj "/CN=localhost"

cat \
  /etc/haproxy/certs/temp.crt \
  /etc/haproxy/certs/temp.key \
  > /etc/haproxy/certs/temp.pem

# IMPORTANT:
# HAProxy cert directory mode requires ONLY PEM files
rm -f /etc/haproxy/certs/*.crt
rm -f /etc/haproxy/certs/*.key

chmod 600 /etc/haproxy/certs/temp.pem


# ------------------------------------------------------------
# Custom HAProxy systemd service
# IMPORTANT:
# Allows directory-based config loading
# and proper PID handling
# ------------------------------------------------------------
cat <<'EOF' >/etc/systemd/system/haproxy.service
[Unit]
Description=HAProxy Load Balancer
After=network-online.target docker.service
Wants=network-online.target

[Service]
ExecStart=/usr/sbin/haproxy -Ws \
  -f /etc/haproxy/haproxy.cfg \
  -f /etc/haproxy/services/ \
  -p /run/haproxy.pid

ExecReload=/bin/kill -USR2 $MAINPID

Restart=always
RestartSec=2

LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# ------------------------------------------------------------
# Validate HAProxy configuration
# ------------------------------------------------------------
echo "==> Validating HAProxy configuration"

haproxy -c \
  -f /etc/haproxy/haproxy.cfg \
  -f /etc/haproxy/services/

# ------------------------------------------------------------
# Enable service (do not start during AMI build)
# ------------------------------------------------------------
systemctl daemon-reload

systemctl enable haproxy

systemctl stop haproxy || true

echo "=== HAProxy AMI provisioning complete ==="
