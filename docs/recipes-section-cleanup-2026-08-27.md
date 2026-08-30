---
title: "Recipes Section Cleanup: Duplication, Broken Images, Flat Layout"
date: 2026-08-27
description: "Diagnosed and fixed why the Hugo recipes section looked wrong: every root-level recipe file was duplicated inside smoke-sessions/ with diverging frontmatter, several images were misplaced or misspelled, and the list layout flattened every subsection into one grid instead of the sectioned structure the index page promised."
tags:
  - hugo
  - recipes
  - content-cleanup
categories:
  - Reference
summary: "Root cause was a stale fork: every root-level recipe file had an identical duplicate under smoke-sessions/, differing only in how the image was wired (frontmatter param vs. inline embed). Combined with a flat, non-sectioned list layout and a couple of broken image paths, the recipes page looked duplicated and inconsistent. Fixed by keeping the smoke-sessions/ copies, restoring correct image frontmatter, moving images into static/images/recipes/, deleting the root duplicates and an orphaned landing page, and rewriting the layout to render explicit sections."
---

## Problem

The recipes section (`/recipes/`) looked broken: a newly created page wasn't showing where expected, some cards had no thumbnail, and the overall page felt inconsistent despite recent content additions.

## Approach

### Diagnosis

Walked the full chain: `content/recipes/_index.md` → `archetypes/recipe.md` → `layouts/recipes/list.html` → the actual content tree.

Found four separate, compounding issues:

1. **Every root-level recipe file was duplicated inside `smoke-sessions/`.** `diff` on all 7 pairs showed identical content — the only difference was how the image was wired: the root copy used `image:` frontmatter (what the layout actually reads for card thumbnails), the `smoke-sessions/` copy dropped that field and instead embedded the image inline in the body with `![]()`. This looked like an old experiment comparing two image techniques that was never cleaned up.

2. **An orphaned page**, `smoke-sessions/recipes.md`, duplicated the job of `content/recipes/_index.md` (same "Structure" prose, same categories) but sat as a regular content page instead of a section index — showing up as a nonsense card in the grid.

3. **`layouts/recipes/list.html` used `.RegularPagesRecursive.ByTitle`**, which recurses through every page under `content/recipes/` regardless of subsection and renders one flat grid. This meant every duplicate rendered as two separate cards, and the sectioned structure described in `_index.md`'s prose (Smoke Sessions / Proteins / Techniques / Reference) was never actually reflected on the page.

4. **A typo'd image path** in a newly created page (`/images/receipes/...` instead of `/images/recipes/...`) produced a broken thumbnail, unrelated to the other three issues but caught in the same pass.

### Fix

- Kept the `smoke-sessions/` copies (correct location per the intended structure), restored the missing `image:` frontmatter field to each from the root copies
- Moved the underlying image files from `static/images/` (root) into `static/images/recipes/` to match the existing convention, and updated all `image:` frontmatter plus inline `![]()` embeds to the new path
- Fixed the `receipes` → `recipes` typo
- Deleted the 7 root-level duplicate files and the orphaned `smoke-sessions/recipes.md`
- Rewrote `layouts/recipes/list.html` to iterate an explicit, ordered list of subsections (Smoke Sessions, Proteins, Techniques, Reference, Baking), rendering a heading + grid per section and only when that section has at least one page — empty sections (e.g. `reference/`, which currently has no content beyond its own `_index.md`) are hidden rather than shown with a placeholder

## Result

- `/recipes/` now renders 4 populated sections in the intended order, each showing only its own pages, with no duplicates
- All thumbnails resolve correctly; no more broken images from path typos or missing frontmatter
- Root of `content/recipes/` now contains only `_index.md` and the 7 legitimate subsection folders (`baking`, `journey`, `proteins`, `reference`, `smoke-sessions`, `techniques`)
- Verified locally via `hugo server -D` before deploying

## Open items

- `journey/` has no content yet and isn't included in the sectioned layout — add it to `layouts/recipes/list.html`'s section list if/when it gets real pages
- `reference/` is currently empty (index page only) — will start showing automatically once it has real content, no further layout change needed
