#!/usr/bin/env bash
set -e

echo "Hardening system..."

systemctl daemon-reload

systemctl enable docker haproxy node_exporter prometheus pushgateway grafana blackbox-exporter

echo "Hardening complete"