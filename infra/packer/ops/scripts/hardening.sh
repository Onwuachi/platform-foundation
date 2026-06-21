#!/usr/bin/env bash

set -e

echo "=== Hardening system ==="

systemctl daemon-reload

#################################
# Core Platform
#
# NOTE: This script runs EARLY in the Packer build (first shell
# provisioner block), before node_exporter, prometheus, grafana,
# and blackbox-exporter systemd unit files have been uploaded.
# Those services are enabled individually later in template.pkr.hcl,
# right after each one's install/file-upload step. Do NOT add
# `systemctl enable` calls for them here — the unit files won't
# exist yet and the build will fail with "Unit file ... does not exist".
#################################

systemctl enable docker

systemctl enable haproxy

#################################
# TLS
#################################

systemctl enable certbot.timer

echo "=== Hardening complete ==="
