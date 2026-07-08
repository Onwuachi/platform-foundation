#!/usr/bin/env bash
# new-kb-domain.sh

set -e

SECTION="$1"

if [[ -z "$SECTION" ]]; then
    echo "Usage: ./new-kb-domain.sh <section>"
    exit 1
fi

BASE="$(git rev-parse --show-toplevel)/apps/hugo/service/content/kb"

FOLDERS=(
  bottles
  buying-guide
  collection
  comparisons
  distilleries
  education
  experiments
  flavor-dna
  journey
  lists
  pairings
  rankings
  references
)

echo "Creating KB domain: $SECTION"

mkdir -p "$BASE/$SECTION"

for folder in "${FOLDERS[@]}"; do
    mkdir -p "$BASE/$SECTION/$folder"
done

cp "$BASE/_index.md" "$BASE/$SECTION/_index.md"

cat > "$BASE/$SECTION/_index.md" <<EOF
---
title: "$(tr '[:lower:]' '[:upper:]' <<< ${SECTION:0:1})${SECTION:1} Knowledge Base"
description: "${SECTION^} wiki."
weight: 20
---
EOF

for folder in "${FOLDERS[@]}"; do
cat > "$BASE/$SECTION/$folder/_index.md" <<EOF
---
title: "$(echo "$folder" | tr '-' ' ' | sed 's/\b\(.\)/\u\1/g')"
description: ""
weight: 10
cascade:
  type: ${SECTION}
---
EOF
done

echo
echo "✅ Created:"
tree "$BASE/$SECTION"

