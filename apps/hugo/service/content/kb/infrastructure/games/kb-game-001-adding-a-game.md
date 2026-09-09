---
title: "KB-GAME-001 — Adding a New Game to the Platform Arcade"
date: 2026-09-05
description: "Checklist and conventions for building, placing, and wiring a new static game into the Hugo games archive."
tags: ["hugo", "games", "static-site", "kb"]
categories: ["infrastructure"]
summary: "Step-by-step process for adding a new game to onwuachi.com/culture/games/, covering file structure, conventions shared across all games, and the exact placement/deploy steps."
---

## Overview

The platform hosts a small arcade of self-contained, static, client-side games — no
database, no backend, pure HTML/CSS/JS served directly through the existing Hugo +
HAProxy pipeline. Each game is a single `index.html` file with everything inlined
(no external JS/CSS dependencies), which keeps deployment trivial: drop the file in
the right static folder, rebuild Hugo, done.

As of this writing the arcade has 6 games: Test Platformer, Breakout, Snake, Space
Shooter, Invaders, and Frogger.

## Repo structure

```
apps/hugo/service/static/games/<game-name>/index.html   ← the actual game, static asset
apps/hugo/service/content/culture/games/_index.md        ← archive landing page (card grid)
apps/hugo/service/content/culture/games/<game-name>.md   ← per-game content page (iframe embed)
apps/hugo/service/static/css/games-grid.css               ← shared card grid styling
```

URL mapping:
- `/games/<game-name>/` → serves the raw static game (the iframe target)
- `/culture/games/<game-name>/` → the Hugo content page that embeds it
- `/culture/games/` → the archive index with all game cards

**Important:** the static file must be named `index.html` (not `<game-name>.html`)
inside its own folder, so the clean URL `/games/<game-name>/` resolves. Naming it
anything else means visitors hit an ugly `/games/<game-name>/<game-name>.html` URL
instead — this has bitten us before (Breakout was initially saved as
`breakout.html` and had to be renamed).

## Shared conventions across every game

Every game file follows the same baseline, established across the platformer,
Breakout, Snake, the shooter, Invaders, and Frogger builds:

- **Viewport meta tag**: `<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">`
  — required for correct mobile scaling. Do not add `user-scalable=no` — that traps
  users with an oversized canvas and no way to zoom out if sizing is ever off.
- **Fullscreen button (⛶)**: uses `requestFullscreen` with vendor-prefix fallbacks
  (`webkitRequestFullscreen`, `msRequestFullscreen`) since plain `requestFullscreen`
  alone under-detects support on many mobile browsers, especially inside an iframe.
  The button hides itself if no variant is supported. Even with prefixes handled,
  iOS Safari in particular may still block fullscreen from inside an iframe — this
  is a known ceiling, not a bug to keep chasing.
- **Pause button (⏸) + Esc key**: freezes the update loop, shows a Resume/Restart
  menu. Wired so pausing never counts as a loss and resuming doesn't cause a
  physics/timer catch-up jump.
- **Mobile touch controls**: on-screen buttons gated behind `@media (pointer: coarse)`,
  hidden on desktop. Landscape mobile layout triggers on `@media (pointer: coarse)
  and (max-height: 500px)` rather than `orientation: landscape` — the latter proved
  unreliable inside an embedded iframe on real devices.
- **`#game-area` flex container**: canvas and touch-controls live together in one
  real flex layout (not `position: fixed` overlays) so the browser genuinely
  reserves space for both instead of controls floating on top of the canvas. This
  was a real bug once — fixed-position controls looked fine in isolation but sat on
  top of the canvas rather than beside/below it once actually tested on a phone.
- **Best-score persistence**: `localStorage` (not `sessionStorage`) so high scores
  survive across visits, not just the current tab session. Keyed per-game, e.g.
  `snake-best`, `invaders-best`, `frogger-best`.
- **Iframe embed attributes**: every `<iframe>` embedding a game in its content
  page must include `allow="fullscreen" allowfullscreen`, or the in-game fullscreen
  button silently does nothing — browsers block fullscreen requests from
  unpermitted iframes by default.

## Checklist: adding a new game

1. **Build the game file** as a single self-contained `index.html`, following the
   shared conventions above (viewport, pause, fullscreen, mobile controls,
   localStorage best score).
2. **Create the static folder and place the file:**
   ```bash
   cd apps/hugo/service/static/games
   mkdir <game-name>
   mv "$DL/<game-name>.html" <game-name>/index.html
   ```
3. **Test locally** — `explorer.exe index.html` from WSL2 opens it directly via
   `file://`, no deploy needed for basic testing. Confirm keyboard controls, mobile
   touch controls (browser dev tools device emulation is a reasonable proxy but
   real-device testing has caught bugs emulation missed), pause/resume, and
   win/lose states.
4. **Create the content page:**
   ```
   apps/hugo/service/content/culture/games/<game-name>.md
   ```
   Frontmatter: `title`, `date`. Body: one-line description, the iframe embed
   (`src="/games/<game-name>/"`, remember `allow="fullscreen" allowfullscreen`),
   and a **Controls:** line.
5. **Add a card to the archive index** at
   `apps/hugo/service/content/culture/games/_index.md`, inside the
   `<div class="games-grid">` block:
   ```html
   <a href="/culture/games/<game-name>/" class="game-card">
     <div class="game-icon">🎮</div>
     <p class="game-title">Game Title</p>
     <p class="game-blurb">One-line hook.</p>
     <p class="game-play">Play →</p>
   </a>
   ```
6. **Deploy:**
   ```bash
   ./scripts/deploy-hugo.sh
   ```
7. **Verify live:**
   - `/culture/games/` shows the new card
   - `/culture/games/<game-name>/` loads the content page with the game embedded
   - `/games/<game-name>/` loads the raw game directly
   - Card link, iframe, and controls all work
   - Test on an actual mobile device if possible, not just emulation — several
     real bugs (landscape sizing, fullscreen support, touch-vs-click event
     mismatches) only surfaced on real hardware

## Known open issues / rough edges

- Fullscreen from inside the iframe embed is not guaranteed to work on all mobile
  browsers, particularly iOS Safari. The vendor-prefix fix widens support but does
  not eliminate every case. No further fix identified yet beyond the fallback
  already in place; a "open in new tab" link is a possible future workaround if
  fullscreen reliability keeps being a problem.
- Games with more complex physics (Frogger's log-riding, wrap-around lane
  entities) use `dt`-scaled movement to stay roughly frame-rate independent —
  worth checking this doesn't drift on longer play sessions if a game runs for a
  long time in one sitting.

## Games built so far

| Game | Path | Notes |
|---|---|---|
| Test Platformer | `/games/platformer/` | 8 levels, double jump, coyote time, character skins |
| Breakout | `/games/breakout/` | Paddle physics, angled bounce based on hit position |
| Snake | `/games/snake/` | Classic grid movement, can't reverse into self |
| Space Shooter | `/games/shooter/` | Free 8-directional movement, escalating waves |
| Invaders | `/games/invaders/` | Classic marching grid, enemies fire back |
| Frogger | `/games/frogger/` | Road + river crossing, log-riding, countdown timer |
