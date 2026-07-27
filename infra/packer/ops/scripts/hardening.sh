#!/usr/bin/env bash

set -euo pipefail

echo "=== Hardening system ==="

#################################
# Validate expected OS
#################################

VERSION=$(lsb_release -rs)

if [[ "$VERSION" != "24.04" ]]; then
    echo "ERROR: Expected Ubuntu 24.04"
    exit 1
fi

#################################
# Kernel limits
#################################

cat >/etc/sysctl.d/99-platform.conf <<EOF
fs.file-max = 2097152
EOF

sysctl --system

#################################
# Login/session limits
#################################

cat >/etc/security/limits.d/99-platform.conf <<EOF
* soft nofile 524288
* hard nofile 524288
root soft nofile 524288
root hard nofile 524288
EOF

#################################
# Reload systemd
#################################

systemctl daemon-reload

#################################
# Core Platform
#
# NOTE: This script runs EARLY in the Packer build.
# Do not enable services whose unit files have not yet
# been copied into /etc/systemd/system.
#################################

systemctl enable docker
systemctl enable haproxy
systemctl enable certbot.timer

echo "=== Hardening complete ==="
