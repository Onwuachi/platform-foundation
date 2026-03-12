#!/usr/bin/env bash
set -e

cd /tmp

curl -LO https://github.com/prometheus/pushgateway/releases/download/v1.6.2/pushgateway-1.6.2.linux-amd64.tar.gz

tar xvf pushgateway-*.tar.gz

mv pushgateway-*/pushgateway /usr/local/bin/

useradd --no-create-home --shell /usr/sbin/nologin pushgateway || true

mkdir -p /var/lib/pushgateway
chown pushgateway:pushgateway /var/lib/pushgateway