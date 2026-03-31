#!/usr/bin/env bash
set -e

echo "==> Gracefully stopping platform"

systemctl stop ops.target || true
systemctl stop haproxy || true
systemctl stop docker || true

echo "==> Syncing state (optional)"
aws s3 sync /opt/platform s3://platform-api-services/platform --exclude "logs/*" || true

echo "==> Shutdown complete"