#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu




echo "=== Starting Docker manually (Packer fix) ==="

# Try systemd first (works on real EC2, might fail in Packer)
systemctl enable docker || true
systemctl start docker || true

#  HARD FALLBACK: start dockerd manually
if ! docker info >/dev/null 2>&1; then
  echo "Systemd failed, starting dockerd manually..."

  nohup dockerd > /var/log/dockerd.log 2>&1 &

  # Wait for daemon
  for i in {1..20}; do
    if docker info >/dev/null 2>&1; then
      echo "Docker is ready"
      break
    fi
    echo "Waiting for Docker..."
    sleep 2
  done
fi

# Final validation (FAIL FAST if still broken)
docker info

