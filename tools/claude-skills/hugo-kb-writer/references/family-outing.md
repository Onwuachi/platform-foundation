# Family Outing Post Template

Source: extracted from `content/family/outings/2026-minnesota-state-fair.md`
(2026 Minnesota State Fair post, built with `tools/hugo/create-family-outing.sh`
and the `family-outing.md` archetype).

Format: **YAML** (`---` delimiters).

Path: `content/family/outings/<slug>.md`

## ⚠️ Privacy rules — read before drafting anything

- Real, identifiable photos of the kids live **outside the repo** at `~/private-family-photos/`.
  They must **never** be referenced in front matter, committed, or suggested as a path.
- Only reference already-anonymized/privacy-safe public images already placed under
  `apps/hugo/service/static/images/family/...`, referenced in front matter as
  `/images/family/<filename>.png`.
- If Derrick pastes a path that looks like it might be the real photo (contains "real",
  points outside `static/`, or he hasn't confirmed it's the anonymized version), stop and
  ask which public image to use — don't guess or carry the path forward.
- Kids are referenced by **age only** (`kids: ["5", "7"]`), never by name, unless Derrick
  explicitly gives a name for that specific post and confirms he wants it included.

## Frontmatter

```yaml
---
title: "2026 Minnesota State Fair"
date: 2026-09-07
description: "One or two sentences: what happened, who was there, how it started/ended."
summary: "One-sentence summary of the outing."
tags: ["family", "outing", "relevant-event-tag", "boys"]
categories: ["family"]
location: "Place Name, City, State"
duration: "Approximately 8:00 AM–4:00 PM"
cost: "Free / actual cost or how tickets were obtained"
kids: ["5", "7"]
season: "summer"
image: "/images/family/slug-name.png"
draft: false
---
```

Field order matters for `sed`-based edits Derrick sometimes uses (e.g. inserting `image:`
right after `season:`) — keep this order unless told otherwise.

## Body structure

```markdown
# <Title>

**Date:** Month Day, Year
**Occasion:** Holiday/event name if applicable

[Narrative account of the outing — first person, chronological, warm/reflective tone
similar to bottle reviews but about the day rather than a product. Can include:]

- How the outing came about (e.g. unexpected gift of tickets)
- What was done, in rough chronological order
- Specific memorable moments
- How it ended

[No rigid subsection headers required like the review/KB templates — this one reads more
like a personal essay/journal entry. Use subheadings only if the outing naturally breaks
into distinct chapters (e.g. "Morning: Arcade Games," "Afternoon: DNR Building").]
```

## Scaffolding

Use `tools/hugo/create-family-outing.sh` to generate the skeleton — confirm the exact
arguments with Derrick since this script is newer and not yet fully documented in this
skill. Do not hand-write the frontmatter from scratch if the script exists; scaffold first,
then fill in.

## Verifying the image is wired up

Adding `image:` to front matter only stores the value — it doesn't guarantee Derrick's Hugo
theme actually renders it. If Derrick is setting up a new outing's image for the first time,
mention (don't assume already known) that the layout templates need to consume
`.Params.image` for it to show as a card/hero image — worth a quick `hugo --minify --gc`
build check and a grep across `layouts/`/`themes/` for `.Params.image` if the image isn't
appearing after deploy.
