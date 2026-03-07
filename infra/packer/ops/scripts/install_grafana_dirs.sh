#!/bin/bash
set -e

mkdir -p /opt/grafana
mkdir -p /opt/grafana/data

chown -R 472:472 /opt/grafana/data
chmod 755 /opt/grafana