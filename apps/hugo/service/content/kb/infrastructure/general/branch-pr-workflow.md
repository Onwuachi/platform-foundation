---
title: "KB-REF-002 — Branch, PR, and Merge Workflow"
date: 2026-09-08
description: "Evergreen reference for platform-foundation's git workflow: branch protection rules on main, the infra/Hugo pre-commit split, and the two-account review process."
tags: ["github", "branch-protection", "git", "pull-requests", "workflow"]
categories: ["Infrastructure"]
summary: "Reference for how commits reach main on platform-foundation: branch protection enforcement, commit-splitting rules, and cross-account PR review."
---

# KB-REF-002 — Branch, PR, and Merge Workflow

## What it is

The standing convention for getting any change onto `main` in
`platform-foundation`. Enforced by GitHub branch protection (not just
documented as a habit) — direct pushes to `main`, including from repo admins,
are rejected.

## The rule

`main` requires:
- A pull request (no direct pushes, bypass disabled for everyone including
  admins)
- At least one approval

## The workflow

```bash
git checkout main
git pull
git checkout -b <short-descriptive-branch-name>

# ... make changes ...

git add <files>
git commit -m "..."

git push -u origin <branch-name>
```

Then open the PR — either from the URL git prints on a new branch's first
push, or via `https://github.com/Onwuachi/platform-foundation/compare/main...<branch-name>`
if the branch already existed remotely (git won't reprint the link on
subsequent pushes to an existing branch).

Review happens from a second GitHub account (`trainbus`) that Derrick also
controls, since a solo repo can't produce independent self-approval. This
keeps the mechanical PR/approve/merge rep intact — it is not independent code
review, and shouldn't be treated as a substitute for one if this repo is ever
opened to other contributors.

After merge:

```bash
git checkout main
git pull
git branch -d <branch-name>              # delete local branch
git push origin --delete <branch-name>   # delete remote branch (GitHub also offers this via a button on the merged PR)
```

## Commit-splitting rule (pre-commit hook enforced)

`tools/git-hooks/pre-commit` blocks any single commit that mixes:
- `infra/`, `.github/`, `scripts/`, or `tools/` paths (treated as infra)
- `apps/hugo/` paths (treated as content)

**One PR/branch can contain both an infra commit and a Hugo commit** — the
split applies per-commit, not per-branch or per-PR. Stage and commit each
category separately:

```bash
git add apps/hugo/service/...
git commit -m "content: ..."

git add tools/... 
git commit -m "tools: ..."

git push
```

Never `git add .` or `git add -A` on this repo without checking `git status`
first — there is almost always unrelated in-progress work sitting in the
working directory (other features, signal files, build artifacts) that
shouldn't ride along in an unrelated PR.

## Verifying the fix actually worked

A merged PR is not proof a bug is fixed — check the Actions tab / PR's Checks
tab and confirm the specific job that was previously failing now passes.
Aggregate counts like "4 of 5 checks passed" can hide the fact that the
originally-broken job specifically didn't run or still failed for a different
reason.

## Known gaps

- CRLF/LF line endings are inconsistent across the repo (at least one workflow
  file is CRLF). Don't fix this incidentally inside an unrelated PR — it makes
  diffs unreviewable. Do it as its own isolated commit if ever addressed.
- `git commit -- <paths> -m "..."` is invalid syntax — `-m` must precede the
  `--` pathspec separator.

## Related

- `tools/git-hooks/pre-commit`
- `docs/branch-protection-and-ci-fixes-2026-09-08.md` — session log for how
  this was set up and the bugs found while establishing it
- `KB-HUGO-001` — Hugo KB Writer Claude skill, built the same session, unrelated
  subject
