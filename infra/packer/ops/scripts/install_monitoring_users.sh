#!/usr/bin/env bash
set -e

for USER in prometheus grafana node_exporter blackbox pushgateway
do
  id "$USER" &>/dev/null || useradd --system --no-create-home --shell /usr/sbin/nologin "$USER"
done