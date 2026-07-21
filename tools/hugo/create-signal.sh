#!/usr/bin/env bash
set -euo pipefail

# create-kb-signal.sh
# Usage: ./create-kb-signal.sh "Title of the signal" <signal_type> ["optional description"]
# signal_type: deployment | incident | recovery | infra-metric | platform-change

SIGNALS_DIR="content/signals"
VALID_TYPES=("deployment" "incident" "recovery" "infra-metric" "platform-change")

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 \"Title\" <signal_type> [\"description\"]"
  echo "Valid signal_type values: ${VALID_TYPES[*]}"
  exit 1
fi

TITLE="$1"
SIGNAL_TYPE="$2"
DESCRIPTION="${3:-}"

# validate signal_type
if [[ ! " ${VALID_TYPES[*]} " =~ " ${SIGNAL_TYPE} " ]]; then
  echo "❌ Invalid signal_type: '${SIGNAL_TYPE}'"
  echo "Valid options: ${VALID_TYPES[*]}"
  exit 1
fi

# slugify title: lowercase, spaces/underscores -> hyphens, strip non-alnum
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')
SLUG="${SLUG}-$(date +%H%M%S)"

DATE=$(date +"%Y-%m-%dT%H:%M:%S%:z")
FILE="${SIGNALS_DIR}/${SLUG}.md"

if [[ -e "$FILE" ]]; then
  echo "❌ File already exists: $FILE"
  exit 1
fi

mkdir -p "$SIGNALS_DIR"

cat > "$FILE" << EOF
---
title: "${TITLE}"
date: ${DATE}
draft: false
signal_type: "${SIGNAL_TYPE}"
description: "${DESCRIPTION}"
---

${DESCRIPTION}
EOF

echo "✅ Created: $FILE"
