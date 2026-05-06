#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=== Installing HAProxy (Clean AMI Build) ==="

# ------------------------------------------------------------
# Base packages
# ------------------------------------------------------------
apt-get update
apt-get install -y software-properties-common rsyslog curl

#add-apt-repository -y ppa:vbernat/haproxy-2.8
apt-get update

apt-get install -y haproxy certbot python3 openssl dos2unix

# ------------------------------------------------------------
# Directory structure
# ------------------------------------------------------------
mkdir -p /etc/haproxy/certs
mkdir -p /etc/haproxy/services

# Ensure HAProxy doesn't fail on empty include dir
touch /etc/haproxy/services/_placeholder.cfg

# ------------------------------------------------------------
# Domain map (safe default for validation)
# ------------------------------------------------------------
echo "default_backend default_backend" > /etc/haproxy/domain.map
dos2unix /etc/haproxy/domain.map || true

# ------------------------------------------------------------
# HAProxy main config (clean + correct)
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
  timeout client 50s
  timeout server 50s

########################################
# HTTP (80)
########################################
frontend http_in
  bind *:80

  # Allow Let's Encrypt challenge
  acl acme_challenge path_beg /.well-known/acme-challenge/
  use_backend certbot_backend if acme_challenge

  acl is_hugo path_beg /hugo
  use_backend hugo_backend if is_hugo

  # Redirect everything else to HTTPS
  http-request redirect scheme https code 301 unless acme_challenge

########################################
# HTTPS (443)
########################################
frontend https_in
  #bind *:443 ssl crt /etc/haproxy/certs/temp.pem
  bind *:443 ssl crt /etc/haproxy/certs/

  # Domain-based routing (core logic)
  use_backend %[req.hdr(host),lower,field(1,:),map(/etc/haproxy/domain.map,default_backend)]


########################################
# BACKENDS
########################################

# Default fallback
backend default_backend
  http-request return status 503 content-type text/plain lf-string "Service not found"

# Certbot challenge handler
backend certbot_backend
  server certbot 127.0.0.1:8089

backend hugo_backend
  http-request set-path %[path,regsub(^/hugo,)]
  server hugo 127.0.0.1:8081
EOF

chmod 644 /etc/haproxy/haproxy.cfg

# ------------------------------------------------------------
# Temporary self-signed cert (AMI-safe)
# ------------------------------------------------------------
echo "==> Creating temporary self-signed cert"

rm -f /etc/haproxy/certs/*

openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/haproxy/certs/temp.key \
  -out /etc/haproxy/certs/temp.crt \
  -subj "/CN=localhost"

cat /etc/haproxy/certs/temp.crt \
    /etc/haproxy/certs/temp.key \
    > /etc/haproxy/certs/temp.pem

# ------------------------------------------------------------
# Validate config (fail build if broken)
# ------------------------------------------------------------
echo "==> Validating HAProxy config"

haproxy -c \
  -f /etc/haproxy/haproxy.cfg \
  -f /etc/haproxy/services/

# ------------------------------------------------------------
# Enable service (do NOT start in AMI)
# ------------------------------------------------------------
systemctl daemon-reload
systemctl enable haproxy
systemctl stop haproxy || true

echo "=== HAProxy AMI provisioning complete ==="
