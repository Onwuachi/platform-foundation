---
title: "Adding a Playable Game to the Platform"
date: 2026-08-02
description: "Proof-of-concept static/client-side game, served through the existing Hugo pipeline with zero new infrastructure, then wired into the live site's Culture section."
tags: ["hugo", "static-site", "frontend"]
categories: ["infrastructure"]
summary: "Built a minimal Canvas platformer as a test of whether the platform's static-file serving path could handle something playful, then integrated it into a real Culture page with actual site navigation — no database, no new services."
---

## Goal

Test whether this platform's existing static-serving pipeline (Hugo → Docker → ECR → SSM refresh) could handle a simple browser game with zero new infrastructure — explicitly avoiding a database or backend service for cost reasons.

## Approach

1. **Proof of concept first, not the real game.** A minimal, dependency-free Canvas platformer (arrow keys + Space, basic gravity/collision against two platforms) dropped as a single static file at `apps/hugo/service/static/games/test/index.html`. Since it's under `static/`, Hugo publishes it unchanged — no template, no build config.
2. **Deployed it through the real pipeline** (`hugo --minify --gc` → `docker build` → ECR push → `platform refresh hugo`) and confirmed it live via `curl` at `onwuachi.com/games/test/` before investing further.
3. **Connected it to the actual site**, since a static file with no site link is effectively invisible:
   - `content/culture/games.md` — a real Hugo content page under the existing Culture section, embedding the test game via `<iframe>` (kept isolated from the site's theme CSS/JS rather than embedded raw, even though `hugo.toml` has `unsafe = true` allowing raw HTML in markdown)
   - `layouts/partials/platform/culture.html` — added a "🎮 Games" card linking to `/culture/games/`, since the `/culture/` list template doesn't automatically enumerate pages under `content/culture/`

## A recurring friction point solved along the way

Manual deploys kept hitting `Token has expired and refresh failed` mid-push, since SSO sessions (correctly) expire, unlike the static admin key they replaced. Built `scripts/ensure-sso.sh` (checks and prompts for re-auth only if needed) and `scripts/deploy-hugo.sh` (wraps the full build/push/refresh sequence with the SSO check built in), collapsing what had been six manually-typed commands into one.

## Result

Confirmed live via `curl`, twice — once for the raw game file, once for the `/culture/` page showing the Games card actually rendered in the HTML output. A real, playable, no-cost feature, reachable from the site's own navigation, built and deployed through the same pipeline as everything else on the platform.

## Next

The game itself is intentionally minimal (a colored rectangle, two platforms, no goal or scoring) — a pipeline test, not a finished feature. Improving it (sprite, animation, a level goal, sound) is a separate, contained task from the infrastructure work above.
