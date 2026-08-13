#!/usr/bin/env bash
# tools/hugo/create-kb-recipe.sh
# Usage: ./create-kb-recipe.sh <subsection> <recipe-name>
# Example: ./create-kb-recipe.sh proteins skillet-fried-chicken
#          ./create-kb-recipe.sh techniques dry-brining
#          ./create-kb-recipe.sh smoke-sessions 2026-labor-day

set -euo pipefail

SUBSECTION="${1:-}"
RECIPE="${2:-}"

VALID_SUBSECTIONS=(proteins techniques smoke-sessions journey reference)

if [[ -z "$SUBSECTION" || -z "$RECIPE" ]]; then
  echo "Usage: ./create-kb-recipe.sh <subsection> <recipe-name>"
  echo ""
  echo "Valid subsections: ${VALID_SUBSECTIONS[*]}"
  echo ""
  echo "Examples:"
  echo "  ./create-kb-recipe.sh proteins skillet-fried-chicken"
  echo "  ./create-kb-recipe.sh techniques dry-brining"
  echo "  ./create-kb-recipe.sh smoke-sessions 2026-labor-day"
  exit 1
fi

VALID=false
for s in "${VALID_SUBSECTIONS[@]}"; do
  if [[ "$s" == "$SUBSECTION" ]]; then
    VALID=true
    break
  fi
done

if [[ "$VALID" != "true" ]]; then
  echo "❌ Unknown subsection: ${SUBSECTION}"
  echo ""
  echo "Valid subsections: ${VALID_SUBSECTIONS[*]}"
  exit 1
fi

HUGO_ROOT="$(git rev-parse --show-toplevel)/apps/hugo/service"
CONTENT_PATH="recipes/${SUBSECTION}/${RECIPE}.md"
FULL_PATH="${HUGO_ROOT}/content/${CONTENT_PATH}"

# Validate subsection exists (it should already, per current recipes/ structure)
if [[ ! -d "${HUGO_ROOT}/content/recipes/${SUBSECTION}" ]]; then
  echo "❌ Subsection not found: content/recipes/${SUBSECTION}/"
  echo ""
  echo "Available subsections:"
  ls "${HUGO_ROOT}/content/recipes/" | grep -v -E '^_index\.md$|\.md$'
  exit 1
fi

# Check if file already exists
if [[ -f "$FULL_PATH" ]]; then
  echo "⚠️  File already exists: ${FULL_PATH}"
  echo "Opening for editing..."
  ${EDITOR:-vi} "$FULL_PATH"
  exit 0
fi

# Create the recipe
cd "$HUGO_ROOT"
hugo new --kind recipe "${CONTENT_PATH}"

echo ""
echo "✅ Created: content/${CONTENT_PATH}"
echo ""
echo "Next steps:"
echo "  1. Fill in frontmatter fields (description, summary, tags, categories)"
echo "  2. Write the recipe content"
echo "  3. Set draft: false when ready to publish"
echo "  4. hugo --minify --gc && platform deploy hugo"
echo ""

# Open in editor
${EDITOR:-vi} "$FULL_PATH"
