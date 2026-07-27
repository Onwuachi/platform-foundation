#!/bin/bash
set -e
mkdir -p /opt/grafana
mkdir -p /opt/grafana/data
mkdir -p /opt/grafana/dashboards
chown -R 472:472 /opt/grafana/data
chown -R 472:472 /opt/grafana/dashboards
chmod 755 /opt/grafana

# SMTP env file placeholder — real values injected by platform-rehydrate.sh
mkdir -p /etc/grafana
touch /etc/grafana/smtp.env
chmod 600 /etc/grafana/smtp.env
