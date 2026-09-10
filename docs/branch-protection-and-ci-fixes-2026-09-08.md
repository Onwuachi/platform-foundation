---
title: "Re-enabling Branch Protection and Fixing CI Path Bugs"
date: 2026-09-08
description: "Session log for re-enabling PR-required branch protection on main (removing an admin bypass), practicing the branch/PR/merge workflow with a second reviewer account, and the CI bugs this surfaced and fixed."
tags: ["github", "branch-protection", "ci-cd", "hugo", "workflow"]
categories: ["engineering"]
summary: "Turned off an admin bypass on main's branch protection as deliberate practice toward DOP-C02/platform-SRE goals, then found and fixed three real CI configuration bugs via the resulting PR review process."
---

# Re-enabling Branch Protection and Fixing CI Path Bugs

## Problem

`main` had branch protection configured but with "Do not allow bypassing the
above settings" left unchecked, meaning admin pushes went straight to `main`
with no PR step. This had been convenient while training solo, but it meant no
PR-review rep was actually happening — a gap against DOP-C02/platform-SRE
goals, which assume daily branch/PR/merge habits. It also meant nothing was
catching configuration drift before it landed on `main`.

## Approach

1. Re-enabled the bypass block: checked "Do not allow bypassing the above
   settings" under `Settings → Branches` for the `main` rule (classic branch
   protection, not the newer Rulesets system — this repo uses the former).
2. Established a working convention: one PR per branch is fine containing both
   an infra commit and a Hugo commit, as long as each individual commit still
   respects the existing `tools/git-hooks/pre-commit` infra/Hugo split.
3. Since this is a solo repo, self-approval isn't possible with "Require
   approvals" also enabled — reviews are done from a second, separately
   authenticated GitHub account (`trainbus`) that Derrick also controls. This
   keeps the mechanical PR/approve/merge rep intact while being honest that
   it isn't independent review.
4. Practiced the full loop across five real PRs:
   - **#8** — family outings feature (archetype, first post, scaffolding
     script) — first real PR under the new protection rule
   - **#9** — games section (7 games) + recipe post updates
   - **#10** — fixed `scripts/build-hugo.sh`: `SITE_DIR` was hardcoded to
     `../apps/hugo/site`, which doesn't exist; corrected to `apps/hugo/service`
   - **#11** — fixed two further stale `apps/hugo/site` references discovered
     via CI logs: `.github/workflows/hugo-ci.yml` (Build Docker image step)
     and `.github/workflows/platform-hugo-deploy.yml` (build step, S3 sync
     path, and a stale filename in its own `paths:` trigger)
   - **#(unnumbered, same session)** — removed `.github/workflows/codeql.yml`,
     a duplicate advanced CodeQL setup conflicting with GitHub's default
     CodeQL setup (both trying to report scan results caused a persistent
     SARIF processing error)

## Notable snags during the process

- **`git commit -- <paths> -m "..."` fails** — `-m` must come before the `--`
  pathspec separator, not after.
- **A commit landed on local `main` instead of a new branch** — happened when
  `git checkout -b <branch>` wasn't actually run before committing. Recovered
  cleanly via `git branch <name>` (branches off current HEAD, keeping the
  commit), then `git checkout main && git reset --hard origin/main` to restore
  `main`, then `git checkout <name>` to continue on the correct branch. No data
  lost since the errant commit had never been pushed (protected `main`
  wouldn't have accepted it anyway).
- **CRLF line endings on `platform-hugo-deploy.yml`** — this file had CRLF
  endings already on `main` (predating this session), which made a 3-line
  content edit look like a full-file rewrite in `git diff`. Confirmed via
  `file <path>` and `git show main:<path> | file -` before deciding: kept the
  existing CRLF convention rather than normalizing it inside an unrelated
  bugfix PR — line-ending cleanup deserves its own dedicated commit if ever
  done.
- **`git push -u origin main` "succeeding"** — this was misleading at first
  glance; it wasn't proof branch protection allowed the push. Local `main` had
  no commits ahead of `origin/main` at the time, so it was a no-op
  ("Everything up-to-date"), not a bypass. Real verification of the block
  requires an actual new commit on local `main` before attempting the push.

## Result

- Branch protection genuinely enforced on `main` — no bypass, admin included.
- Three real CI misconfigurations found and fixed that had been silently
  failing for an unknown period (all pre-dated this session):
  - `scripts/build-hugo.sh` wrong `SITE_DIR`
  - `.github/workflows/hugo-ci.yml` wrong path in Docker build step
  - `.github/workflows/platform-hugo-deploy.yml` wrong paths in three places,
    plus a stale self-referential filename in its trigger config
- Duplicate/conflicting CodeQL workflow removed; GitHub's default CodeQL setup
  is now the sole code-scanning source, clearing the "Code scanning
  configuration error" on the repo's Security page.
- Five PRs merged end-to-end (branch → commit(s) → push → PR → cross-account
  review → merge), each following the pre-commit hook's infra/Hugo commit
  split correctly.

## Known follow-ups

- CRLF vs LF convention across the repo is inconsistent (at least
  `platform-hugo-deploy.yml` is CRLF while other files are LF) — worth a
  deliberate, isolated normalization pass at some point, not mixed into
  unrelated work.
- `signals/refreshed-hugo-*.md` accumulation (currently 16+ files) needs a
  retention policy — Derrick wants to keep roughly the last 10, but the
  underlying `create-signal.sh`/refresh mechanism needs review first; deferred
  to a dedicated session.
- Two Dependabot alerts on the `qs` npm package
  (`apps/api/service/package-lock.json`) remain open — unrelated app, separate
  from Hugo/platform work covered here.
- `phase-3-platform-autoprovision` branch is active elsewhere in the repo and
  wasn't touched this session.

## Related

- `docs/hugo-kb-writer-skill-2026-09-08.md` — the Claude skill built earlier in
  this same session, unrelated subject
- `tools/git-hooks/pre-commit`
- `.github/workflows/hugo-ci.yml`
- `.github/workflows/platform-hugo-deploy.yml`
