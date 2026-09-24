---
title: "awsp.sh: Sourcing It From .bashrc Actually Works"
date: 2026-09-15
description: "awsp (the SSO profile switcher) was added to scripts/ but never wired into .bashrc — grep confirmed the source line was missing, not that the script was broken."
tags: ["aws", "sso", "bash", "tooling"]
categories: ["infrastructure"]
summary: "awsp status/awsp <profile> failed with 'command not found' after adding awsp.sh to scripts/; root cause was a missing source line in .bashrc, not a bug in the script itself — confirmed via grep, fixed, and verified against the platform-foundation SSO profile."
---

## Problem

After moving `awsp.sh` into `scripts/`, running `awsp status` or
`awsp platform-foundation` failed:

```
Command 'awsp' not found, did you mean:
  command 'aws' from snap aws-cli (1.45.46)
  ...
```

## Approach

`awsp` must be sourced into the shell (not just present on disk) because it
exports `AWS_PROFILE` as a shell function, not a standalone executable. The
intended install step — `echo 'source scripts/awsp.sh' >> ~/.bashrc` — had
been planned but never actually run in this shell.

Confirmed via direct grep rather than assuming:

```bash
grep -n awsp ~/.bashrc
```

Returned nothing — no match. The source line was genuinely absent from
`.bashrc`, not just unsourced in the current shell.

## Fix

```bash
echo 'source ~/cicd/platform-foundation/scripts/awsp.sh' >> ~/.bashrc
source ~/.bashrc
```

## Verification

```bash
awsp status
```
```
⚠  Note: ~/.aws/credentials has a [default] profile with static keys.
   Any AWS call without an explicit profile falls back to it.
Current profile: platform-foundation
Token: expired or invalid
```

Function loaded correctly and detected the current `AWS_PROFILE` (already
set via `export AWS_PROFILE=platform-foundation` earlier in `.bashrc`) —
just needed a fresh token. Re-authenticating:

```bash
awsp platform-foundation
```
```
SSO token missing or expired for 'platform-foundation' — reauthenticating...
Attempting to automatically open the SSO authorization page in your default browser.
gio: https://oidc.us-east-1.amazonaws.com/authorize?...: Operation not supported
Successfully logged into Start URL: https://d-90667959c1.awsapps.com/start/#/
Active profile: platform-foundation
+--------------+---------------------------------------------------------------------------------------------------------+
|    Account   |                                                   Arn                                                   |
+--------------+---------------------------------------------------------------------------------------------------------+
|  046685909731|  arn:aws:sts::046685909731:assumed-role/AWSReservedSSO_AdministratorAccess_f50dee0be7e8265a/donwuachi  |
+--------------+---------------------------------------------------------------------------------------------------------+
```

Resolved to the correct account (`046685909731`) with
`AdministratorAccess`, confirming both the fix and the script's
account-verification behavior work end-to-end. The `gio: Operation not
supported` line is the known WSL2 browser-hook limitation (see
`docs/sso-cutover-2026-08-01.md`) — cosmetic, not a failure; the CLI falls
through to the printed URL and completes normally.

## Diff

Only change was the missing line appended to `~/.bashrc` (not tracked in
git — this is local shell config, not part of the repo):

```diff
--- a/~/.bashrc (before)
+++ b/~/.bashrc (after)
@@ end of file
+source ~/cicd/platform-foundation/scripts/awsp.sh
```

No changes to `awsp.sh` itself were required — the script was correct as
committed. This confirms the bug was purely an install/wiring gap, not a
script defect.

## `ensure-sso.sh` vs. `awsp.sh` — when to use which

Both exist in `scripts/` and can look redundant at a glance. They solve
different problems:

| | `ensure-sso.sh` | `awsp.sh` |
|---|---|---|
| Purpose | Confirm current session is alive; re-auth if not | Switch which profile/account you're acting as |
| Scope | One fixed profile (defaults to `${AWS_PROFILE:-platform-foundation}`) | Any profile in `~/.aws/config` |
| Invocation | Run (called from other scripts, e.g. `deploy-hugo.sh`) | Sourced (changes the calling shell's `AWS_PROFILE`) |
| Typical use | Inside automation, before a deploy/build step | Interactively, before starting work, especially across multiple accounts |

`ensure-sso.sh` answers "is my session still good?" `awsp` answers "which
account am I acting as, and is *that* session good?" For Platform
Foundation specifically (single profile, already exported permanently in
`.bashrc`), `ensure-sso.sh` covers most automation needs on its own; `awsp`
becomes more valuable once juggling multiple SSO profiles across separate
AWS Organizations.

## Known follow-up (not yet done)

`awsp status`/`awsp <profile>` doesn't currently warn on near-expiry the
way `ensure-sso.sh` does (its <15-minute-remaining check). Worth porting
that check into `awsp` so both scripts share the same freshness logic
instead of diverging.
