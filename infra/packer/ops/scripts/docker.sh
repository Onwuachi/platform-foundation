#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

echo "=== Installing Docker ==="

curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu

echo "=== Configuring Docker defaults ==="

mkdir -p /etc/docker

cat >/etc/docker/daemon.json <<EOF
{
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Soft": 524288,
      "Hard": 524288
    }
  }
}
EOF

echo "=== Starting Docker (Packer fix) ==="

# Try systemd first
systemctl enable docker || true
systemctl restart docker || true

# Fallback for environments where systemd isn't fully functional
if ! docker info >/dev/null 2>&1; then
    echo "Systemd failed, starting dockerd manually..."

    nohup dockerd >/var/log/dockerd.log 2>&1 &

    for i in {1..20}; do
        if docker info >/dev/null 2>&1; then
            echo "Docker is ready"
            break
        fi

        echo "Waiting for Docker..."
        sleep 2
    done
fi

echo "=== Validating Docker ==="

docker info
docker version
containerd --version

echo "=== Validating Docker default ulimits ==="

cat /etc/docker/daemon.json

docker run --rm busybox sh -c 'ulimit -n'
