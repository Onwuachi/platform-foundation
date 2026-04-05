#!/usr/bin/env bash
set -e

IMAGE=$(grep IMAGE_URI /etc/platform/api.env | cut -d= -f2)

echo "Checking for new image..."

OLD=$(docker inspect --format='{{.Image}}' platform-api 2>/dev/null || true)

docker pull $IMAGE

NEW=$(docker inspect --format='{{.Id}}' $IMAGE)

if [ "$OLD" = "$NEW" ]; then
  echo "Already running latest image"
  exit 0
fi

echo "New image detected — restarting service"

systemctl restart platform-api