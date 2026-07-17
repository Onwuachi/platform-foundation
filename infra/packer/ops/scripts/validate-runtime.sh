#!/bin/bash
set -euo pipefail

echo "=== Docker Runtime Validation ==="

docker version

echo "=== Docker daemon config ==="

cat /etc/docker/daemon.json


echo "=== Container test ==="

docker run --rm busybox sh -c 'ulimit -n'


echo "=== Expected ==="

echo "524288"
