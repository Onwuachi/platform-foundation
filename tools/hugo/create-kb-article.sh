#!/usr/bin/env bash
# tools/hugo/create-kb-article.sh
# Usage: ./create-kb-article.sh <section> <subsection> <article-name>
# Example: ./create-kb-article.sh infrastructure hugo front-matter
#          ./create-kb-article.sh infrastructure docker compose-networking
#          ./create-kb-article.sh infrastructure aws iam-roles

set -euo pipefail

SECTION="${1:-}"
SUBSECTION="${2:-}"
ARTICLE="${3:-}"

if [[ -z "$SECTION" || -z "$SUBSECTION" || -z "$ARTICLE" ]]; then
  echo "Usage: ./create-kb-article.sh <section> <subsection> <article-name>"
  echo ""
  echo "Examples:"
  echo "  ./create-kb-article.sh infrastructure hugo front-matter"
  echo "  ./create-kb-article.sh infrastructure docker compose-networking"
  echo "  ./create-kb-article.sh infrastructure aws iam-roles"
  exit 1
fi

HUGO_ROOT="$(git rev-parse --show-toplevel)/apps/hugo/service"
CONTENT_PATH="kb/${SECTION}/${SUBSECTION}/${ARTICLE}.md"
FULL_PATH="${HUGO_ROOT}/content/${CONTENT_PATH}"

# Validate section exists
if [[ ! -d "${HUGO_ROOT}/content/kb/${SECTION}" ]]; then
  echo "❌ Section not found: content/kb/${SECTION}/"
  echo ""
  echo "Available sections:"
  ls "${HUGO_ROOT}/content/kb/"
  exit 1
fi

# Create subsection if it doesn't exist
if [[ ! -d "${HUGO_ROOT}/content/kb/${SECTION}/${SUBSECTION}" ]]; then
  echo "📁 Creating subsection: kb/${SECTION}/${SUBSECTION}/"
  mkdir -p "${HUGO_ROOT}/content/kb/${SECTION}/${SUBSECTION}"
  title=$(echo "$SUBSECTION" | tr '-' ' ' | sed 's/\b\(.\)/\u\1/g')
  cat > "${HUGO_ROOT}/content/kb/${SECTION}/${SUBSECTION}/_index.md" << INDEXEOF
---
title: "${title}"
description: ""
---
INDEXEOF
  echo "✅ Created _index.md for ${SUBSECTION}"
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
hugo new --kind kb-article "${CONTENT_PATH}"

echo ""
echo "✅ Created: content/${CONTENT_PATH}"
echo ""
echo "Next steps:"
echo "  1. Fill in frontmatter fields (description, summary, tags)"
echo "  2. Write the article content"
echo "  3. Set draft = false when ready to publish"
echo "  4. hugo --minify --gc && platform deploy hugo"
echo ""

# Open in editor
${EDITOR:-vi} "$FULL_PATH"
