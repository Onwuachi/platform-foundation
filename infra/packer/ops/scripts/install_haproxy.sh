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
  stats socket /run/haproxy/admin.sock mode 660 level admin

defaults
  mode http
  log global
  option httplog
  timeout connect 5s
  timeout client 50s
  timeout server 50s


frontend http_in
    bind *:80

    # rate limiting
    stick-table type ip size 1m expire 30m
    http-request track-sc0 src
    http-request deny if { sc_http_req_rate(0) gt 50 }

    # allow certbot challenges
    acl acme_challenge path_beg /.well-known/acme-challenge/
    use_backend certbot_backend if acme_challenge

    # redirect everything else to HTTPS
    default_backend redirect_https


# platform core routes
frontend https_in
    bind *:443 ssl crt /etc/haproxy/certs/onwuachi.com.pem

    acl is_api path_beg /api
    acl is_ready path /ready
    acl is_payments path_beg /payments
    acl is_analytics path_beg /analytics
    acl is_billings path_beg /billings

    use_backend platform_api if is_api or is_ready
    use_backend payments_backend if is_payments
    use_backend analytics_backend if is_analytics
    use_backend billings_backend if is_billings

    default_backend hugo_backend

backend dummy_backend
  mode http
  http-request return status 503 content-type text/plain lf-string "Service initializing... Platform not ready"

backend platform_api
    option httpchk GET /ready
    http-check expect status 200
    http-request replace-path ^/api(/.*)? \1
    server api1 127.0.0.1:3000 check

backend hugo_backend
    option httpchk GET /
    http-check expect status 200
    server hugo1 127.0.0.1:8080 check

backend billings_backend
    http-request replace-path ^/billings(/.*)? \1
    server billings 127.0.0.1:3030 check

backend analytics_backend
    http-request replace-path ^/analytics(/.*)? \1
    server analytics 127.0.0.1:3040 check

backend payments_backend
    http-request replace-path ^/payments(/.*)? \1
    server payments 127.0.0.1:3050 check

backend redirect_https
    redirect scheme https code 301

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
haproxy -c -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/services/

# ------------------------------------------------------------
# Enable service but DO NOT start it in AMI build
# ------------------------------------------------------------
sudo systemctl daemon-reload
systemctl enable haproxy
systemctl stop haproxy || true

echo "=== HAProxy AMI provisioning complete ==="
