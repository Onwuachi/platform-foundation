#!/bin/bash
set -euo pipefail

echo "=== Installing ECR Credential Helper ==="

apt-get update
apt-get install -y amazon-ecr-credential-helper

#########################################
# Configure Docker for ROOT (systemd)
#########################################
mkdir -p /root/.docker

cat >/root/.docker/config.json <<EOF
{
  "credsStore": "ecr-login"
}
EOF

#########################################
# Configure Docker for ubuntu/ssm-user (optional)
#########################################
mkdir -p /home/ubuntu/.docker || true
cat >/home/ubuntu/.docker/config.json <<EOF
{
  "credsStore": "ecr-login"
}
EOF

chown -R ubuntu:ubuntu /home/ubuntu/.docker || true

echo "=== ECR Credential Helper Configured ==="
