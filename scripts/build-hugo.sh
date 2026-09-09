#!/usr/bin/env bash
set -e

SITE_DIR="apps/hugo/service"
OUTPUT_DIR="dist"

cd "$SITE_DIR"

hugo --minify --destination "$OUTPUT_DIR"
