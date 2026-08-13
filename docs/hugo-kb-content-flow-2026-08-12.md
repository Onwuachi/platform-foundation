---
title: "Hugo KB Content Creation Flow"
date: 2026-08-12
description: "How new domains, bottles, and recipes actually get created and published in the Hugo KB, and why tools/control-cli exists but isn't part of that flow."
tags:
  - hugo
  - kb
  - tooling
categories:
  - Reference
summary: "Reference doc distinguishing the working create-kb-*.sh scaffolding scripts from the dormant tools/control-cli (ctl) auto-generation system, so the split doesn't have to get re-derived later."
---

## Problem

Two separate systems exist in this repo for producing Hugo KB content:

1. `tools/hugo/create-kb-*.sh` — scaffolding scripts, actively used
2. `tools/control-cli/ctl` + `domains/*/mappings.yaml` — a note-to-page generator, mostly unbuilt

Nothing in the repo documented which one is real. This doc is the map.

## Approach

### The working flow: `tools/hugo/create-kb-*.sh`

All three scripts scaffold a file via `hugo new`, using an archetype, then open it in `$EDITOR` for manual editing. None of them auto-generate content — they create structure and get out of the way.

**1. New domain (once per topic)**

```
tools/hugo/create-kb-domain.sh <topic> --base kb|private
```

Scaffolds `content/<base>/<topic>/` with the standard subfolder set (bottles, buying-guide, collection, etc.). `--base` picks whether the domain lives under the public `content/kb/` or the gated `content/private/`. Bourbon, rum, beer, and scotch already exist under `private/` — this only runs again for a genuinely new topic.

**2. New bottle entry (per bottle)**

```
tools/hugo/create-kb-bottle.sh <spirit> <bottle-name> --base kb|private
```

Runs `hugo new --kind <spirit>-bottle`, using the matching `<spirit>-bottle.md` archetype (e.g. `bourbon-bottle.md`). Validates the archetype and the domain folder exist first. Opens the new file for editing.

**3. New recipe (per dish or technique)**

```
tools/hugo/create-kb-recipe.sh <subsection> <recipe-name>
```

Subsection is one of the existing `content/recipes/` folders: `proteins`, `techniques`, `smoke-sessions`, `journey`, `reference`. Runs `hugo new --kind recipe` using `archetypes/recipe.md`. Doesn't scaffold new subsections — those five are treated as fixed.

**Common tail end for all three:**

- Fill in frontmatter (`title`, `date`, `description`, `tags`, `categories`, `summary`)
- Write the body
- Set `draft: false` when ready to publish
- Commit (infra and Hugo/content changes as separate commits, per existing convention)
- `platform deploy hugo`

### The dormant flow: `tools/control-cli` (`ctl`)

`ctl` is a small Python script (`tools/control-cli/ctl`) built around a different idea: paste in a raw session note, and it extracts `## Overview`/`## Observations`/`## Decisions`-style sections and renders them into a template automatically, rather than starting from a blank archetype.

Usage: `tools/control-cli/ctl <domain> <rule> <source_file>`

Each domain has a `mappings.yaml` declaring its `rules`, which template each rule uses, and where the output goes.

**Current state per domain, as of this doc:**

- `domains/recipes/mappings.yaml` — the only domain with a real, working template (`templates/ribs.md.tpl`). Its `sources:` block still points at `content/kb/recipes/...`, which is stale — recipes live at `content/recipes/...` directly, not under `kb/`. `sources:` isn't actually read by `ctl` (confirmed by reading `generate()` in `ctl`), so this is a documentation-only inaccuracy, not a functional bug.
- `domains/bourbon/mappings.yaml` — `templates.bottle` points at `domains/bourbon/templates/bottle.md.tpl`, which doesn't exist. `generators/` and `templates/` under this domain are both empty. Running `ctl bourbon bottle_entry <file>` would fail immediately with `FileNotFoundError`. `sources:` was updated to `content/private/bourbon/bottles/` to reflect the actual move, but again this field isn't read by `ctl`.
- `domains/infrastructure/mappings.yaml` — not fully audited in this pass; only `recipes` and `bourbon` were checked in depth.
- No `mappings.yaml` exists for rum, beer, or scotch. Those domains were scaffolded manually and haven't been wired into `ctl` at all.

**Why it's not part of the real flow today:** every bottle and recipe entry so far has gone through `create-kb-bottle.sh` / `create-kb-recipe.sh` and manual editing, not `ctl`. `ctl` was set up for at least one domain (recipes) but never finished or adopted as the actual workflow.

## Result

- `tools/hugo/create-kb-*.sh` is the real, current content-creation path — confirmed working end to end for domains, bottles, and recipes.
- `tools/control-cli` (`ctl`) is speculative/unfinished tooling for a different workflow (auto-drafting from raw notes). Only `recipes` has a working template; `bourbon` is broken if invoked; `rum`/`beer`/`scotch` were never wired up.
- Decision on `ctl`'s future is open — deferred until there's an actual desire to auto-draft pages from notes rather than hand-write them via the archetype scripts.

## Open items

- If `ctl` is ever picked back up: `domains/bourbon/templates/bottle.md.tpl` needs to be written, `rules.bottle_entry.output: bottles/` needs to resolve into `content/private/bourbon/bottles/` (currently resolves relative to `tools/control-cli/`, landing nowhere useful), and `domains/recipes/mappings.yaml`'s `sources:` block should be corrected to `content/recipes/...` for documentation accuracy even though it's unused by the script.
- `rum`/`beer`/`scotch` `control-cli` mappings, if wanted, still need to be created from scratch — hold off per earlier decision not to touch anything there without reviewing what already exists first.
