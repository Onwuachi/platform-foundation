# Technical KB Article Template

Source: confirmed conventions from Derrick (frontmatter fields, ID scheme, path structure).
**No full example article body was pasted for this type** — unlike bottle reviews and
smoke sessions, this template's frontmatter is confirmed but the body structure below
is a reasonable default based on standard runbook/reference conventions, not an extracted
real file. If Derrick has strong opinions on body structure, ask/update this file with a
real pasted example the first time this skill is used for a tech KB article.

Format: **YAML** (`---` delimiters).

Path: `content/kb/<category>/<subcategory>/<slug>.md` — categories seen in the repo include
`infrastructure/aws`, `infrastructure/docker`, `infrastructure/gcp`, `infrastructure/general`,
`infrastructure/hugo`, `infrastructure/systemd`, `infrastructure/terraform`,
`infrastructure/onwua-portfolio`.

## Frontmatter

```yaml
---
title: "KB-XXX-### — Short Descriptive Title"
date: 2026-08-22
description: "One-sentence factual description of the problem or reference this covers."
tags:
  - relevant-tool
  - relevant-topic
categories:
  - Infrastructure
summary: "One-sentence summary of the fix/reference, similar to description but can differ slightly in framing."
---
```

## KB ID scheme

Format: `KB-<CATEGORY>-<###>`, zero-padded three digits, sequential per category.

Known categories in use (confirmed against the repo, not assumed): `GAME`, `HUGO`,
`NET`, `OBS`, `REF`, `WEB`. Each currently at `-001` unless otherwise confirmed in-session.

Examples on file: `KB-GAME-001`, `KB-HUGO-001`, `KB-NET-001`, `KB-OBS-001`, `KB-REF-001`
(now also `KB-REF-002`), `KB-WEB-001`.

**To assign a new ID:** identify the right category from the topic, then ask Derrick to
confirm the current highest number in that category (or check if he's pasted/shared the KB
article list in this session) before assigning the next one — don't guess a number that
might collide with an existing article.

If the topic doesn't fit an existing category cleanly, propose a new category prefix and
confirm with Derrick before using it.

## Body structure (default — confirm/adjust with Derrick on first real use)

```markdown
# <Title>

Brief one-paragraph summary of the problem/topic and why it matters.

---

# Problem   (for issue/fix articles — omit for pure reference/cheat-sheet articles)

[What went wrong, symptoms observed, error messages.]

---

# Root Cause

[What was actually happening, traced through investigation.]

---

# Fix / Solution

[Steps taken, commands run, config changed. Use fenced code blocks for exact commands.]

---

# Verification

[How to confirm the fix worked — specific commands/checks, matching Derrick's
runbook-with-verification-steps preference.]

---

# Related

- Links to related KB articles, scripts, or repo paths if applicable
```

For pure cheat-sheet/reference articles (e.g. `KB-REF-001` file-format cheat sheet), the
Problem/Root Cause/Fix structure doesn't apply — these are likely closer to a flat reference
table or command list. Ask Derrick which shape fits before drafting if the topic is a
reference doc rather than an incident writeup.

## Note on separate `docs/` convention

Derrick distinguishes two doc locations:
- `docs/` — dated engineering session writeups (own frontmatter: title/date/description/tags/categories/summary,
  Problem/Approach/Result structure), used for one-off session logs
- Hugo KB (`content/kb/...`) — evergreen topic-reference articles, not tied to a specific session

If it's unclear whether something belongs in `docs/` vs the Hugo KB, ask Derrick — this
skill is scoped to the Hugo KB only. If he wants a `docs/` writeup instead, mention that's a
different location/convention rather than drafting it as a KB article.
