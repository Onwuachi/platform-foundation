#!/usr/bin/env bash
# tools/hugo/create-kb-anime.sh
# Usage: ./create-kb-anime.sh <anime-name> [--base kb|private]
# Example: ./create-kb-anime.sh daemons-of-the-shadow-realm --base private
#          ./create-kb-anime.sh boruto --base private

set -euo pipefail

ANIME="${1:-}"
shift 1 || true

BASE_NAME="private"

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

if [[ -z "$ANIME" ]]; then
  echo "Usage: ./create-kb-anime.sh <anime-name> [--base kb|private]"
  echo ""
  echo "Examples:"
  echo "  ./create-kb-anime.sh daemons-of-the-shadow-realm --base private"
  echo "  ./create-kb-anime.sh boruto --base private"
  exit 1
fi

if [[ "$BASE_NAME" != "kb" && "$BASE_NAME" != "private" ]]; then
    echo "❌ Invalid --base value: $BASE_NAME (must be 'kb' or 'private')"
    exit 1
fi

HUGO_ROOT="$(git rev-parse --show-toplevel)/apps/hugo/service"
ARCHETYPE="anime"
CONTENT_PATH="${BASE_NAME}/anime/${ANIME}.md"
FULL_PATH="${HUGO_ROOT}/content/${CONTENT_PATH}"

# Validate archetype exists
if [[ ! -f "${HUGO_ROOT}/archetypes/${ARCHETYPE}.md" ]]; then
  echo "❌ Archetype not found: archetypes/${ARCHETYPE}.md"
  exit 1
fi

# Validate domain exists
if [[ ! -d "${HUGO_ROOT}/content/${BASE_NAME}/anime" ]]; then
  echo "❌ Domain not found: content/${BASE_NAME}/anime/"
  echo ""
  echo "Create it first:"
  echo "  $(git rev-parse --show-toplevel)/tools/hugo/create-kb-domain.sh anime --base ${BASE_NAME}"
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

${EDITOR:-vi} "$FULL_PATH"

