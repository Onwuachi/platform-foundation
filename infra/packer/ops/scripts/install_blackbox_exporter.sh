#!/bin/bash
set -e

BLACKBOX_VERSION="0.28.0"

mkdir -p /opt/blackbox
cd /opt/blackbox

curl -LO https://github.com/prometheus/blackbox_exporter/releases/download/v${BLACKBOX_VERSION}/blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64.tar.gz

tar xzf blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64.tar.gz

mv blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64/blackbox_exporter /opt/blackbox/blackbox_exporter

chmod +x /opt/blackbox/blackbox_exporter

chown -R blackbox:blackbox /opt/blackbox

rm -rf blackbox_exporter-${BLACKBOX_VERSION}.linux-amd64*