# Hugo Site Reorg — Changelog

Everything below was verified against the actual files in `service_tar.gz`,
not from memory. Apply this over `apps/hugo/service/` (e.g. `git diff` it,
or extract the tarball on top and review with `git status` before committing).

## Homepage → Portal

- **`layouts/index.html`** — rewritten. It no longer duplicates `/platform/`.
  It's now: hero → 4 portal cards (Platform / Knowledge Base / Recipes /
  Culture) → a live "Latest Updates" feed (auto-pulls the 6 most recently
  dated pages with real content, via `WordCount gt 0` so empty stub files
  never show up) → footer quote.
- **`layouts/platform/list.html`** — rewritten. This is now the *only* place
  the full dashboard lives (metrics, pipeline, architecture, services,
  observability, recovery, roadmap). It absorbed the modules that used to be
  duplicated on the homepage.
- **`static/css/custom.css`** — added `.portal-grid` / `.portal-card` /
  `.portal-icon` / `.portal-link` styles, consistent with your existing
  design tokens (`--card-bg`, `--accent`, `--muted`, etc.) — no new colors
  introduced.

## Partial duplication cleanup

You had two parallel partial trees (`partials/platform/*` — old, inline
styles — and `partials/modules/platform/*` — new, class-based) with the same
names (`hero.html`, `architecture.html`) doing the same job differently.
The homepage used one, `/platform/` used a mix of both.

**Deleted** (confirmed fully unreferenced before removal):
- `layouts/partials/platform/hero.html`
- `layouts/partials/platform/architecture.html` (+ its `.bak`)
- `layouts/partials/platform/header.html` — old duplicate nav/header with
  dead links to `/ops/` and `/learn/` (routes that don't exist)
- `layouts/partials/platform/footer.html` — superseded by `core/footer.html`
- `layouts/partials/platform/intro.html`, `links-panel.html`,
  `flavor-map.html`, `layouts/partials/badge.html` — all empty, unreferenced
- `layouts/index.html-bak`

`/platform/list.html` now points exclusively at `modules/platform/*` for
hero/architecture/etc. No more duplicate partials with the same name.

## `/culture/` fixes

- **`layouts/culture/list.html`** — was rendering an *entire second header*
  (`partial "platform/header.html"`) above the real site nav, plus a hero
  whose subtitle read "Immutable infrastructure + platform engineering"
  under the "Culture" heading. Both removed. Now shows title/content from
  `_index.md`, the culture module, news, footer quote.
- **`layouts/culture/single.html`** — was missing `{{ define "main" }}`,
  meaning any individual culture page you add would render as a raw
  fragment with no nav, no CSS, no footer. Fixed to extend `baseof.html`
  properly (breadcrumb, title, date, content, then the anime-links sidebar).
- **`layouts/partials/platform/culture.html`** — was rendering the same
  anime-links data twice (once as a plain list, once as a card grid) and
  had a *hardcoded* "Current Hits" list that had drifted from
  `data/culture/links.yaml`. Fixed: hardcoded list removed, now pulls from
  `site.Data.culture.links.favorites`. The data file was updated to include
  every title that was in the hardcoded version — nothing was dropped, it's
  just data-driven now, so editing the yaml is enough going forward.

## Recipes

- **Front matter**: all 7 recipe files got an explicit `image:` field
  pointing at their real thumbnail path.
- **`layouts/recipes/list.html`** — simplified. It used to have a
  hand-maintained slug → filename lookup table that required a template
  edit for every new recipe. Now it just reads `.Params.image`. Add a new
  recipe with an `image:` field in front matter and it shows up
  automatically — no template changes needed.

## Misc

- **`content/kb/email-onwua-com.md`** — this file was sitting at the
  *service root* (`apps/hugo/service/email-onwua-com.md`), outside
  `content/` entirely, so it was never actually published. Its own header
  said it belonged at `content/kb/email-onwua-com.md` — moved there.
- **`content/kb/_index.md`** — didn't exist; `/kb/` was rendering with
  Hugo's bare default title. Added a proper title/description.

## Explicitly NOT touched

- The ~60 empty bourbon KB files (reviews, comparisons, distilleries,
  education, experiments, flavor-dna, pairings, references, buying-guide,
  collection) — confirmed these are intentional stubs you're filling in
  over time. Left alone.
- Taxonomy config (`distillery`/`brand`/`producer` in `hugo.toml`) — already
  in place from your earlier session, not re-touched.
- No new sections, no new content — this pass was templates/structure only.

## Round 2: light/dark theme fix

- **Root cause**: `hugo.toml` never configured `[markup.highlight]`, so
  Hugo used its default Chroma syntax highlighter behavior — which injects
  a fixed "monokai" palette as *inline* hex-color styles directly onto
  every fenced code block (e.g. `style="background-color:#272822"`).
  Inline styles beat your CSS variables, so any page with a fenced code
  block (mostly KB infra pages, docker-networking-ssm.md,
  file-formats-cheatsheet.md, sed-cheatsheet.md, cloudfront-directory-paths.md,
  email-onwua-com.md, and the high-heat-mixed-smoke recipe) had a code
  block that never responded to the theme toggle — always the same fixed
  dark box regardless of light/dark mode. That's the grey/white-out effect.
- **`hugo.toml`** — added `[markup.highlight] noClasses = false`, which
  makes Chroma emit CSS classes (`.chroma .kw`, `.chroma .s`, etc.) instead
  of inline colors.
- **`static/css/custom.css`** — added a `.chroma .*` block that maps those
  token classes to your existing theme variables (`--accent`, `--green`,
  `--muted`, `--text`, `--yellow`, `--red`) instead of Chroma's built-in
  palette. Code blocks now flip correctly with the rest of the site.
- I don't have a `hugo` binary or network access in this environment to
  actually run a build and eyeball the result — this is a correct-per-docs
  fix for a well-known Hugo default, but do check it visually after you
  build, especially the KB pages with code blocks in both themes.

## Round 3: Quick Stats, Platform Snapshot, image cleanup

- **`layouts/partials/modules/platform/quick-stats.html`** (new) — 4-tile
  row on the homepage: Knowledge Articles, Pitmaster Runbooks, Bottle
  Reviews, Platform Services. All four are computed at build time from
  real content (`WordCount gt 0` filters, same trick as Latest Updates),
  not hardcoded numbers. Note: Bottle Reviews will show **0** right now,
  correctly, since those files are still empty stubs — the count will
  climb honestly as you fill them in rather than lying about it.
- **`layouts/partials/modules/platform/snapshot.html`** (new) — "Platform
  Snapshot" card on the homepage. I did **not** build the
  Terraform/AMI/Docker/State tiles from the earlier mockup as literal text,
  because there's no data source backing those specific claims anywhere in
  the repo — hardcoding "AMI: Current" with nothing to verify it would be
  exactly the kind of stale/fabricated status the reorg has been trying to
  eliminate. Instead this reuses `data/signals/telemetry.yaml` — the same
  real data your `/platform/` Telemetry section already reads — shown
  compactly with a link through to the full platform page.
- **`layouts/index.html`** — wired both in: hero → quick stats → portal
  cards → platform snapshot → latest updates → footer.
- **Image cleanup**:
  - Deleted `static/images/bak/` entirely (6 files, ~9MB) — confirmed zero
    references anywhere in content or layouts before removing.
  - Deleted `static/images/derricks-bourbon-journey.png` (the old v1) —
    both pages that reference the bourbon journey image were already
    pointing at `-v2`, so v1 was orphaned.
  - Renamed `derricks-bourbon-journey-v2.png` → `derricks-bourbon-journey.png`
    and updated both markdown references, so the filename doesn't carry a
    version number Git already tracks for you.

## Suggested next pass (not done yet)

- `partials/platform/` vs `partials/modules/platform/` naming is now
  non-duplicated but still inconsistent (two directories for one concept).
  Worth a rename-only pass once you're not mid-build.
- Bourbon taxonomy frontmatter backfill across the 22+ real bottle files,
  whenever you're ready to make `/distilleries/`, `/brands/` etc. real.
