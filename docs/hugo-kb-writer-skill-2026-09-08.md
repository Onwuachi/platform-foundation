---
title: "Building the Hugo KB Writer Claude Skill"
date: 2026-09-08
description: "Session log for designing and drafting a Claude skill that generates Hugo KB articles, bottle reviews, recipes/smoke sessions, and family outing posts matched to Platform Foundation's real frontmatter conventions."
tags: ["claude-skills", "hugo", "content-automation", "kb"]
categories: ["engineering"]
summary: "Designed a 5-content-type Claude skill (tech KB, bottle reviews, recipes, family outings) for drafting Hugo content, with privacy and pre-commit-hook safeguards baked in."
---

# Building the Hugo KB Writer Claude Skill

## Problem

Content creation for the Hugo site (tech KB articles, bourbon/rum/beer reviews, recipes,
family outings) was ad hoc per session — no consistent template enforcement, no
memory of the real frontmatter shapes across content types, and repeated
re-explaining of conventions each time. Also wanted to reduce how much raw
context needs to be re-pasted per writing session.

## Approach

Built a Claude skill (`hugo-kb-writer`) via the skill-creator process:

1. Scoped the trigger narrowly — explicit requests only ("write this up," "create a
   KB entry"), not any passing mention of a KB topic, to avoid the skill firing
   unwantedly mid-conversation.
2. Extracted real templates directly from existing repo files rather than inventing
   generic ones:
   - Bottle reviews (bourbon/rum/beer) — TOML frontmatter, `*-bottle` archetypes,
     narrative Nose/Palate/Finish structure with comparison notes and a
     verdict block
   - Recipes/smoke sessions — YAML frontmatter, operational/log-style structure
     (Objectives → Timeline → Lessons Learned → Runbook Updates Generated)
   - Family outings — YAML frontmatter, journal-style narrative, with explicit
     privacy safeguards (real vs. anonymized photo paths, age-only kid references)
3. Discovered mid-session (via pasted `git status` and `ls tools/hugo/`) that the
   repo already had more scaffolding than initially known: a dedicated
   `create-kb-recipe.sh`, a new `create-family-outing.sh`, a `family-outing.md`
   archetype, and — critically — a real pre-commit hook
   (`tools/git-hooks/pre-commit`) that hard-blocks any commit mixing
   `infra/`/`scripts/`/`tools/` paths with `apps/hugo/` paths.
4. Explicitly scoped games out of this skill — games are static app trees, not
   markdown content, and belong to the separate arcade-builder skill.
5. Added a hard rule: the skill must never guess at unverified facts (bottle
   proof, ABV) *or* unverified tooling syntax (script flags) — ask and confirm
   rather than fabricate either.
6. Ran manual test-prompt dry runs (a non-trigger passing mention, and a full
   rum-review draft) against the drafted skill to validate trigger discipline
   and output shape before finalizing.

## Result

Five-content-type skill (`tools/claude-skills/hugo-kb-writer/`) with:

- `SKILL.md` — trigger discipline, workflow steps, pre-commit-hook-aware commit
  guidance, no-fabrication rule for both content facts and script syntax
- `references/bottle-review.md` — extracted from real bourbon/beer/rum files
- `references/recipe-smoke-session.md` — extracted from a real smoke session log
- `references/family-outing.md` — extracted from a real family outing post, with
  privacy safeguards
- `references/tech-kb.md` — built from confirmed conventions; **flagged as
  unverified** since no real tech KB article body was available this session —
  should be corrected against a real example on first actual use

Skill has no filesystem/shell access to the repo — it drafts articles, scaffold
commands, and commit messages for Derrick to paste and run, matching his existing
paste-and-confirm workflow rather than claiming to execute anything.

## Known follow-ups

- Verify `tech-kb.md`'s assumed body structure against a real KB article the
  next time one is drafted
- Confirm whether scotch reviews use the bourbon archetype/template as-is, or
  need their own (no `scotch-bottle.md` archetype currently exists despite
  scotch content being present)
- Confirm actual `create-*.sh` script usage/flags the first time each is
  invoked through the skill, rather than relying on inferred syntax

## Update — same session, continued

After the skill was built and pushed, this session also produced an unrelated
but consequential change: branch protection on `main` was re-enabled (removing
an admin bypass that had been in place), and the resulting PR-based workflow
surfaced three real, previously-undetected CI bugs (stale `apps/hugo/site`
paths, a duplicate CodeQL workflow). See
`docs/branch-protection-and-ci-fixes-2026-09-08.md` for that full writeup —
kept separate since it's a distinct subject from the KB writer skill itself.
