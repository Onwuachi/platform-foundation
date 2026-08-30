#!/bin/bash
set -euo pipefail

################################################################
# check-docker-disk.sh
#
# Checks root disk usage on ops-01 and Docker's reclaimable
# space. Warns above a threshold; with --prune, reclaims
# unused images/containers/build cache via `docker system
# prune -af`.
#
# Run locally via: platform shell, then paste/run on the box.
# (No local Docker daemon on WSL2 dev machine is assumed.)
################################################################

THRESHOLD="${THRESHOLD:-80}"   # warn if root disk usage % >= this
DO_PRUNE=false

for arg in "$@"; do
  case "$arg" in
    --prune) DO_PRUNE=true ;;
    -h|--help)
      echo "Usage: $0 [--prune]"
      echo "  --prune   Also run 'docker system prune -af' if usage exceeds threshold"
      echo "  THRESHOLD env var overrides the default 80% warning level"
      exit 0
      ;;
  esac
done

echo "=== Root disk usage ==="
df -h /

USAGE_PCT=$(df --output=pcent / | tail -1 | tr -dc '0-9')

echo ""
echo "=== Docker disk usage ==="
if command -v docker >/dev/null 2>&1; then
  docker system df
else
  echo "docker command not found or not on PATH for this user (try: sudo bash)"
  exit 1
fi

echo ""
if [ "$USAGE_PCT" -ge "$THRESHOLD" ]; then
  echo "⚠️  Root disk usage is ${USAGE_PCT}% (threshold: ${THRESHOLD}%)"
  if [ "$DO_PRUNE" = true ]; then
    echo "Running docker system prune -af --volumes ..."
    docker system prune -af --volumes
    echo ""
    echo "=== Root disk usage after prune ==="
    df -h /
  else
    echo "Re-run with --prune to reclaim unused Docker images/containers/build cache."
  fi
else
  echo "✅ Root disk usage is ${USAGE_PCT}%, below ${THRESHOLD}% threshold — no action needed."
fi
