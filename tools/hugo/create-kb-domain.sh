#!/usr/bin/env bash
# tools/hugo/create-kb-domain.sh
# Usage: ./create-kb-domain.sh <section> [--base kb|private]
# Example: ./create-kb-domain.sh mezcal
#          ./create-kb-domain.sh gin --base private
#          ./create-kb-domain.sh whiskey --base kb

set -e

SECTION="$1"
shift || true

BASE_NAME="kb"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      BASE_NAME="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$SECTION" ]]; then
    echo "Usage: ./create-kb-domain.sh <section> [--base kb|private]"
    exit 1
fi

if [[ "$BASE_NAME" != "kb" && "$BASE_NAME" != "private" ]]; then
    echo "❌ Invalid --base value: $BASE_NAME (must be 'kb' or 'private')"
    exit 1
fi

BASE="$(git rev-parse --show-toplevel)/apps/hugo/service/content/${BASE_NAME}"

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

echo "Creating domain: $SECTION (base: content/${BASE_NAME}/)"

mkdir -p "$BASE/$SECTION"

for folder in "${FOLDERS[@]}"; do
    mkdir -p "$BASE/$SECTION/$folder"
done

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
