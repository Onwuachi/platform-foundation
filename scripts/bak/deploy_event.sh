#!/usr/bin/env bash
set -e

HOST=$1

echo "deploy_event 1" | \
curl --data-binary @- http://$HOST:9091/metrics/job/deploy