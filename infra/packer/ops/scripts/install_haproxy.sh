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

defaults
  mode http
  log global
  option httplog
  timeout connect 5s
  timeout client 50s
  timeout server 50s


frontend http_in
  bind *:80
  http-request redirect scheme https code 301

frontend https_in
  bind *:443 ssl crt /etc/haproxy/certs/onwuachi.com.pem

  # platform core routes
  acl is_api path_beg /api
  acl is_ready path /ready
  use_backend platform_api if is_api or is_ready

  # 🚀 dynamic routing (THIS IS YOUR PLATFORM ENGINE)
  use_backend %[path,field(2,/)]_backend
  #use_backend %[path,regsub(^/([^/]+).*,\1)]_backend   ## Next Level

  #default_backend dummy_backend
  default_backend hugo_backend

backend dummy_backend
  mode http
  http-request return status 503 content-type text/plain lf-string "Service initializing...Platform engineering takes time..check with devops"

backend platform_api
  option httpchk GET /ready
  http-check expect status 200
  server api1 127.0.0.1:3000 check

backend hugo_backend
  server hugo1 127.0.0.1:8080 check
EOF

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
haproxy -c -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/services/

# ------------------------------------------------------------
# Enable service but DO NOT start it in AMI build
# ------------------------------------------------------------
sudo systemctl daemon-reload
systemctl enable haproxy
systemctl stop haproxy || true

echo "=== HAProxy AMI provisioning complete ==="
