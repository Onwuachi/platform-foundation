---
title: "KB-HUGO-001 — Hugo KB Writer Claude Skill"
date: 2026-09-08
description: "Reference for the hugo-kb-writer Claude skill: what it does, its five content types, trigger phrasing, and its safety/privacy constraints."
tags: ["claude-skills", "hugo", "content-automation", "kb", "family-privacy"]
categories: ["Infrastructure"]
summary: "Evergreen reference for the Claude skill that drafts Hugo KB articles, bottle reviews, recipes/smoke sessions, and family outing posts matched to Platform Foundation's real conventions."
---

# KB-HUGO-001 — Hugo KB Writer Claude Skill

## What it is

A Claude skill (`tools/claude-skills/hugo-kb-writer/`) that drafts Hugo content for
Platform Foundation across five content types, matched exactly to this repo's
real frontmatter conventions and archetypes rather than generic templates.

## Content types covered

| Type | Path | Format | Reference file |
|------|------|--------|-----------------|
| Technical KB article | `content/kb/<category>/...` | YAML, `KB-XXX-###` IDs | `references/tech-kb.md` |
| Bottle review (bourbon/rum/scotch/beer) | `content/private/<category>/bottles/...` | TOML, `*-bottle` type | `references/bottle-review.md` |
| Recipe / smoke session log | `content/recipes/...` | YAML, operational log style | `references/recipe-smoke-session.md` |
| Family outing post | `content/family/outings/...` | YAML, journal style | `references/family-outing.md` |

Games are explicitly **out of scope** — they're static app trees handled by the
separate arcade-builder skill, not markdown content.

## How to trigger it

Explicit requests only — the skill will not fire on a passing mention of bourbon,
a recipe, or an infra topic. Say things like:

- "Write this up as a KB entry"
- "Create a bottle review for X"
- "Log this smoke session"
- "Write up the family outing"

## What it produces

For any request, three things together:

1. A complete draft article (frontmatter + body) matching the real template for
   that content type
2. The correct `tools/hugo/create-*.sh` scaffold command to generate the file
   skeleton — the skill will ask rather than guess at script flags/arguments it
   hasn't seen confirmed
3. A git commit message scoped correctly against the repo's pre-commit hook

## Safety constraints baked in

- **No filesystem/shell access.** The skill drafts everything for Derrick to
  paste and run himself — it never claims to have created a file, run a script,
  or made a commit.
- **No fabrication.** Unknown facts (proof, ABV, MSRP) and unknown tooling
  syntax (script flags) are left blank/flagged for confirmation rather than
  guessed.
- **Pre-commit hook awareness.** `tools/git-hooks/pre-commit` hard-blocks any
  commit mixing `infra/`/`scripts/`/`tools/` paths with `apps/hugo/` paths. The
  skill only ever proposes Hugo-scoped commits and calls out infra changes as
  needing a separate commit.
- **Family privacy safeguards.** Real, identifiable photos of the kids live
  outside the repo (`~/private-family-photos/`) and must never be referenced in
  a draft or commit. Kids are referenced by age only, never by name, unless
  explicitly provided for that specific post. Any pasted path that looks
  identifying gets flagged before use, not silently included.

## Known limitations

- `references/tech-kb.md`'s body structure is inferred from conventions, not
  extracted from a real tech KB article — should be corrected against a real
  example on first use.
- No dedicated archetype exists yet for scotch reviews (`scotch-bottle.md` is
  absent from `apps/hugo/service/archetypes/` despite scotch content existing)
  — the skill currently assumes the bourbon template applies.
- `tools/hugo/create-*.sh` script usage/flags haven't been independently
  verified by the skill — confirm actual usage the first time each script is
  invoked through it.

## Related

- `tools/claude-skills/hugo-kb-writer/SKILL.md`
- `tools/git-hooks/pre-commit`
- `docs/hugo-kb-writer-skill-2026-09-08.md` — session log for how this skill was built
