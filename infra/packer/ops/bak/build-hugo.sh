#!/usr/bin/env bash
set -euo pipefail

echo "==> Building Hugo site"

HUGO_SITE_DIR="/opt/hugo/site"
PUBLIC_DIR="$HUGO_SITE_DIR/public"

export HUGO_GIT_COMMIT=$(git rev-parse --short HEAD || echo "unknown")
export HUGO_BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

rm -rf "$PUBLIC_DIR"

docker run --rm \
  -e HUGO_GIT_COMMIT \
  -e HUGO_BUILD_TIME \
  -v "$HUGO_SITE_DIR:/site" \
  -w /site \
  klakegg/hugo:ext \
  --destination /site/public \
  --minify

echo "✅ Hugo build complete"
