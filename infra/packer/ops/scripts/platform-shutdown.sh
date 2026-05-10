#!/usr/bin/env bash
set -euo pipefail

echo "======================================="
echo " PLATFORM GRACEFUL SHUTDOWN"
echo "======================================="

SERVICES_DIR="/opt/platform/services"

########################################
# STOP PLATFORM SERVICES
########################################

echo
echo "==> Stopping platform services"

if [ -f "${SERVICES_DIR}/services.list" ]; then

  while read -r SERVICE; do

    [ -z "$SERVICE" ] && continue

    echo "Stopping platform-${SERVICE}"

    systemctl stop "platform-${SERVICE}" || true

  done < "${SERVICES_DIR}/services.list"

fi

########################################
# STOP EDGE
########################################

echo
echo "==> Stopping HAProxy"

systemctl stop haproxy || true

########################################
# STOP MONITORING
########################################

echo
echo "==> Stopping monitoring stack"

systemctl stop prometheus || true
systemctl stop grafana || true
systemctl stop node_exporter || true
systemctl stop blackbox-exporter || true
systemctl stop pushgateway || true

########################################
# DEBUG
########################################

echo
echo "==> Remaining containers"

docker ps -a || true

########################################
# STOP DOCKER
########################################

echo
echo "==> Stopping Docker"

systemctl daemon-reexec || true
systemctl stop docker || true

echo
echo "======================================="
echo " PLATFORM SHUTDOWN COMPLETE"
echo "======================================="
