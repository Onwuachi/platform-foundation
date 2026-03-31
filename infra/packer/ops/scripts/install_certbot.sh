#!/usr/bin/env bash
set -e

export DEBIAN_FRONTEND=noninteractive

# Create acme user (safe if exists)
id -u acme &>/dev/null || useradd -r -s /usr/sbin/nologin acme


# Webroot for ACME challenge
mkdir -p /var/www/certbot
chown -R acme:acme /var/www/certbot
chmod 755 /var/www/certbot

# Platform persistent paths (CRITICAL for packer phase)
mkdir -p /opt/platform/bin-utils
mkdir -p /opt/platform/certs

###Base Directory "bin-utils" for general utility scripts (e.g. certs management, log management, etc.)
mkdir -p /opt/platform/bin-utils
mkdir -p /opt/platform/certs
chmod -R 775 /opt/platform

chown -R ubuntu:ubuntu /opt/platform



apt-get update
apt-get install -y certbot


sudo systemctl daemon-reexec
