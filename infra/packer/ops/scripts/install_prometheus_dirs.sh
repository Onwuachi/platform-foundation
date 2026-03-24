#!/bin/bash
set -e

mkdir -p /opt/prometheus
mkdir -p /opt/prometheus/data
mkdir -p /opt/prometheus/rules

chown -R 65534:65534 /opt/prometheus/data
chmod 755 /opt/prometheus