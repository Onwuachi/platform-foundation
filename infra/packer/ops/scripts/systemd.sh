#!/usr/bin/env bash
set -e

echo "=== Installing systemd units ==="

cp /tmp/systemd/* /etc/systemd/system/

systemctl daemon-reexec
systemctl daemon-reload

#################################
# Enable core platform
#################################

systemctl enable ops.target
systemctl enable platform-api.service
systemctl enable haproxy.service

#################################
# Platform lifecycle
#################################

systemctl enable platform-rehydrate.service

#################################
# Hugo
#################################

systemctl enable hugo.service
systemctl enable hugo-sync.timer

#################################
# Certbot
#################################

systemctl enable certbot.timer

echo "=== systemd setup complete ==="

