#!/bin/bash
set -e

echo "Rehydrating platform..."

# Restore HAProxy service configs
if [ -d /opt/platform/services ]; then
  cp /opt/platform/services/*.cfg /etc/haproxy/services/ || true
fi

# Reload HAProxy
systemctl reload haproxy || true

# Restart platform services
if [ -f /opt/platform/services.list ]; then
  while read service; do
    systemctl restart platform-$service || true
  done < /opt/platform/services.list
fi

echo "Rehydrate complete"

