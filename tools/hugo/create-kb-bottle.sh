#!/usr/bin/env bash
# tools/hugo/create-kb-bottle.sh
# Usage: ./create-kb-bottle.sh <spirit> <bottle-name> [--base kb|private]
# Example: ./create-kb-bottle.sh bourbon rare-breed --base private
#          ./create-kb-bottle.sh rum appleton-estate-12-year --base private
#          ./create-kb-bottle.sh beer goose-island-bourbon-county-brand-stout --base private
#          ./create-kb-bottle.sh whiskey redbreast-12 --base kb

set -euo pipefail

SPIRIT="${1:-}"
BOTTLE="${2:-}"
shift 2 || true

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

if [[ -z "$SPIRIT" || -z "$BOTTLE" ]]; then
  echo "Usage: ./create-kb-bottle.sh <spirit> <bottle-name> [--base kb|private]"
  echo ""
  echo "Examples:"
  echo "  ./create-kb-bottle.sh bourbon rare-breed --base private"
  echo "  ./create-kb-bottle.sh rum appleton-estate-12-year --base private"
  echo "  ./create-kb-bottle.sh beer goose-island-bourbon-county-brand-stout --base private"
  exit 1
fi

if [[ "$BASE_NAME" != "kb" && "$BASE_NAME" != "private" ]]; then
    echo "❌ Invalid --base value: $BASE_NAME (must be 'kb' or 'private')"
    exit 1
fi

HUGO_ROOT="$(git rev-parse --show-toplevel)/apps/hugo/service"
ARCHETYPE="${SPIRIT}-bottle"
CONTENT_PATH="${BASE_NAME}/${SPIRIT}/bottles/${BOTTLE}.md"
FULL_PATH="${HUGO_ROOT}/content/${CONTENT_PATH}"

# Validate archetype exists
if [[ ! -f "${HUGO_ROOT}/archetypes/${ARCHETYPE}.md" ]]; then
  echo "❌ Archetype not found: archetypes/${ARCHETYPE}.md"
  echo ""
  echo "Available archetypes:"
  ls "${HUGO_ROOT}/archetypes/" | grep -v default | sed 's/\.md//'
  echo ""
  echo "To create a new archetype:"
  echo "  cp ${HUGO_ROOT}/archetypes/bourbon-bottle.md ${HUGO_ROOT}/archetypes/${ARCHETYPE}.md"
  echo "  vi ${HUGO_ROOT}/archetypes/${ARCHETYPE}.md"
  exit 1
fi

# Validate domain exists
if [[ ! -d "${HUGO_ROOT}/content/${BASE_NAME}/${SPIRIT}" ]]; then
  echo "❌ Domain not found: content/${BASE_NAME}/${SPIRIT}/"
  echo ""
  echo "Create it first:"
  echo "  $(git rev-parse --show-toplevel)/tools/hugo/create-kb-domain.sh ${SPIRIT} --base ${BASE_NAME}"
  exit 1
fi

# Check if file already exists
if [[ -f "$FULL_PATH" ]]; then
  echo "⚠️  File already exists: ${FULL_PATH}"
  echo "Opening for editing..."
  ${EDITOR:-vi} "$FULL_PATH"
  exit 0
fi

# Create the article
cd "$HUGO_ROOT"
hugo new --kind "${ARCHETYPE}" "${CONTENT_PATH}"

echo ""
echo "✅ Created: content/${CONTENT_PATH}"
echo ""
echo "Next steps:"
echo "  1. Fill in frontmatter and content"
echo "  2. Set draft = false when ready to publish"
echo "  3. hugo --minify --gc && platform deploy hugo"
echo ""

# Open in editor
${EDITOR:-vi} "$FULL_PATH"
