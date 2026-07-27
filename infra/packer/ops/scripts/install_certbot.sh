#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "=== Installing Certbot ==="

#################################
# ACME User
#################################

id -u acme &>/dev/null || useradd \
  -r \
  -s /usr/sbin/nologin \
  acme

#################################
# ACME Webroot
#################################

mkdir -p /var/www/certbot

chown -R acme:acme /var/www/certbot

chmod 755 /var/www/certbot

#################################
# Platform directories
#################################

mkdir -p /opt/platform/bin-utils

mkdir -p /opt/platform/certs

chmod -R 775 /opt/platform

chown -R ubuntu:ubuntu /opt/platform

#################################
# Install Certbot
#################################

apt-get update

apt-get install -y certbot

#################################
# Install renewal hook
#
# NOTE: Packer's `provisioner "shell" { scripts = [...] }`
# uploads each script to a randomized /tmp/packer-shell-XXXX
# path on the remote machine, then executes it from there.
# It does NOT preserve a predictable /tmp/scripts/ directory.
#
# So we can't reference a sibling script by path here — it
# won't exist. Instead, the renewal hook content is written
# inline below to guarantee it's present regardless of how
# Packer stages the shell scripts.
#################################

mkdir -p /etc/letsencrypt/renewal-hooks/deploy

cat > /etc/letsencrypt/renewal-hooks/deploy/haproxy-renew.sh << 'HOOKEOF'
#!/usr/bin/env bash
set -euo pipefail

PRIMARY_DOMAIN="${RENEWED_DOMAINS%% *}"
DEST="/etc/haproxy/certs/${PRIMARY_DOMAIN}.pem"

cat \
  "$RENEWED_LINEAGE/fullchain.pem" \
  "$RENEWED_LINEAGE/privkey.pem" \
  > "$DEST"

chmod 600 "$DEST"

echo "Updated HAProxy certificate: $DEST"

systemctl reload haproxy
HOOKEOF

chmod 755 /etc/letsencrypt/renewal-hooks/deploy/haproxy-renew.sh

#################################
# Enable timer
#################################

systemctl enable certbot.timer

systemctl daemon-reexec

echo "=== Certbot installed ==="
