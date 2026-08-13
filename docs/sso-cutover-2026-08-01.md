---
title: "SSO Cutover: Retiring serverless-admin for Local/Interactive Access"
date: 2026-08-01
description: "Closing the open item from the 2026-07-27 SSO setup — switching local terminal and platform CLI usage from the static serverless-admin key to IAM Identity Center SSO."
tags: ["iam", "sso", "security", "wsl2"]
categories: ["infrastructure"]
summary: "Confirmed the serverless-admin static key was still the active local credential (used moments earlier via SSM), completed the SSO login flow from WSL2, made it the default profile, verified the cutover live, and deactivated the old key."
---

## Background

The `sso-setup-2026-07-27.md` writeup built IAM Identity Center SSO as a replacement for `serverless-admin` — an IAM user with full `AdministratorAccess` and no MFA — but left the actual cutover as an open decision. Today's session found the reason it mattered wasn't hypothetical: `serverless-admin`'s access key had a `LastUsedDate` of moments earlier in this same session, via SSM. It wasn't leftover from old training use, as first suspected — it was the live local credential every `platform` CLI and `aws` command was quietly authenticating through.

## What `AWS_PROFILE` actually does

For anyone reading this back later: `AWS_PROFILE` is an environment variable — a setting held in a terminal session's memory — that the AWS CLI (and anything built on it, like the `platform` tool) checks automatically to decide which named profile in `~/.aws/config` to use. Without it set, every command needs an explicit `--profile <name>` flag, or silently falls back to `[default]`.

- `export AWS_PROFILE=platform-foundation` sets it for the *current* terminal only — gone the moment that window closes.
- Appending the same line to `~/.bashrc` makes every *future* terminal set it automatically on open, since `.bashrc` runs on every new shell.

Both were needed: one for immediate effect, one for permanence.

## WSL2-specific snag

`aws sso login` attempts to auto-open a browser via `gio`, which doesn't exist in this WSL2 setup:

```
gio: https://oidc.us-east-1.amazonaws.com/authorize?...: Operation not supported
```

That error is cosmetic — the login process stays alive and waiting regardless. The fix is to manually copy the printed authorization URL into a Windows-side browser, approve it there, and let the CLI sit until it prints `Successfully logged into Start URL: ...`. Pressing Ctrl+C after the `gio` error (the first attempt) kills the waiting process before the browser approval can land, producing a confusing "Token has expired and refresh failed" on the next command even though no successful login had happened yet.

## Steps taken

1. Confirmed `serverless-admin`'s key was still live via `aws iam get-access-key-last-used`
2. Ran `aws sso login --profile platform-foundation`, completed browser approval manually (WSL2 workaround above)
3. Verified identity: `aws sts get-caller-identity --profile platform-foundation` returned `assumed-role/AWSReservedSSO_AdministratorAccess_.../donwuachi`
4. Set `AWS_PROFILE=platform-foundation` for the current session and permanently via `~/.bashrc`
5. Verified the cutover live: `platform shell` returned a `SessionId` prefixed `donwuachi-...`, versus the previous `serverless-admin-...`
6. Deactivated the old key: `aws iam update-access-key --status Inactive --user-name serverless-admin`

## Result

Local/interactive AWS access now runs through named, MFA-capable SSO identity rather than a shared static key. `serverless-admin`'s key is deactivated (not yet deleted — kept reversible for a watch period in case anything unaccounted-for still depends on it). The IAM user itself, and whether to delete it outright or scope it down, remains a decision for later — same open item, smaller now.
