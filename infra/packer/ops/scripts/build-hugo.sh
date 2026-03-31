#!/usr/bin/env bash
set -euo pipefail

echo "==> Building Hugo site"

HUGO_SITE_DIR="/opt/hugo/site"
PUBLIC_DIR="$HUGO_SITE_DIR/public"

if [ ! -d "$HUGO_SITE_DIR" ]; then
  echo "❌ Missing Hugo site dir"
  exit 1
fi

rm -rf "$PUBLIC_DIR"

docker run --rm \
  -v "$HUGO_SITE_DIR:/site" \
  -w /site \
  klakegg/hugo:ext \
  --destination /site/public \
  --minify

echo "✅ Hugo build complete"
