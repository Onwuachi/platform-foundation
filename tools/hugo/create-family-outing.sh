#!/usr/bin/env bash
# tools/hugo/create-family-outing.sh
#
# Usage:
#   ./create-family-outing.sh <outing-name>
#
# Examples:
#   ./create-family-outing.sh 2026-minnesota-state-fair
#   ./create-family-outing.sh 2026-caponi-art-park
#   ./create-family-outing.sh 2026-zoo-trip

set -euo pipefail

OUTING="${1:-}"

if [[ -z "$OUTING" ]]; then
  echo "Usage: ./create-family-outing.sh <outing-name>"
  echo ""
  echo "Examples:"
  echo "  ./create-family-outing.sh 2026-minnesota-state-fair"
  echo "  ./create-family-outing.sh 2026-caponi-art-park"
  echo "  ./create-family-outing.sh 2026-zoo-trip"
  exit 1
fi

HUGO_ROOT="$(git rev-parse --show-toplevel)/apps/hugo/service"
CONTENT_DIR="${HUGO_ROOT}/content/family/outings"
CONTENT_PATH="family/outings/${OUTING}.md"
FULL_PATH="${HUGO_ROOT}/content/${CONTENT_PATH}"

# Ensure family content structure exists
mkdir -p "${CONTENT_DIR}"

# Create subsection index if needed
if [[ ! -f "${CONTENT_DIR}/_index.md" ]]; then
  cat > "${CONTENT_DIR}/_index.md" <<'INDEXEOF'
---
title: "Family Outings"
description: "Family trips, activities, adventures, and memorable days."
---
INDEXEOF

  echo "✅ Created family/outings/_index.md"
fi

# Check if file already exists
if [[ -f "$FULL_PATH" ]]; then
  echo "⚠️  File already exists:"
  echo "   ${FULL_PATH}"
  echo ""
  echo "Opening for editing..."
  ${EDITOR:-vi} "$FULL_PATH"
  exit 0
fi

cd "$HUGO_ROOT"

# Create the article from the family-outing archetype
hugo new --kind family-outing "${CONTENT_PATH}"

# Validate that Hugo processed the archetype
if grep -q '{{' "$FULL_PATH"; then
  echo "❌ Generated file still contains Hugo template syntax:"
  echo "   ${FULL_PATH}"
  echo ""
  echo "Inspect the archetype:"
  echo "   ${HUGO_ROOT}/archetypes/family-outing.md"
  exit 1
fi

echo ""
echo "✅ Created: content/${CONTENT_PATH}"
echo ""
echo "Next steps:"
echo "  1. Fill in frontmatter"
echo "  2. Record the outing details"
echo "  3. Capture what the kids enjoyed"
echo "  4. Record unexpected/memorable moments"
echo "  5. Record lessons learned"
echo "  6. Set draft: false when ready"
echo "  7. hugo --minify --gc"
echo ""

${EDITOR:-vi} "$FULL_PATH"
