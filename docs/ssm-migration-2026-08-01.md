---
title: "Migrating Web Management from SSH to SSM"
date: 2026-08-01
description: "Replacing SSH-based start/stop/upgrade scripts with SSM Run Command, targeted by instance tag instead of IP, using the existing GitHub OIDC role."
tags: ["ssm", "oidc", "github-actions", "haproxy", "docker", "iam", "security"]
categories: ["infrastructure"]
summary: "Retired three SSH-based web management scripts in favor of one SSM-based script that targets the instance by a stable tag, survives AMI rehydrates, and drops the last static SSH key and secrets from CI."
---

## Problem

`start-web.sh`, `stop-web.sh`, and `upgrade-web.sh` SSH'd into the `ops` instance using a static key (`SSH_PRIVATE_KEY` GitHub secret) and a hardcoded `EC2_PUBLIC_IP` secret. Two issues:

- **Static SSH key in CI**, inconsistent with the OIDC-based access already used for Packer builds and Terraform deploys.
- **IP-based targeting**, which breaks the moment the instance is replaced — and this platform replaces the instance on every Packer AMI roll by design (stateless/immutable rehydrate model). The IP secret had to be manually updated after every rebuild.

## Fix

Replaced all three scripts with a single `scripts/manage-web.sh`, taking `start`/`stop`/`upgrade` as an argument and dispatching via `aws ssm send-command` against `AWS-RunShellScript`, targeted by `Key=tag:Name,Values=ops-01` instead of an IP or instance ID.

Why the tag: the `Name` tag is set in Terraform (`infra/main.tf`) and is stable across every instance replacement — unlike the instance ID (new on every rehydrate) or the public IP (also reassigned on replacement, though re-associated to the same EIP).

```bash
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=tag:Name,Values=$INSTANCE_NAME" \
  --parameters "commands=[\"$COMMAND\"]"
```

The corresponding workflow (`manage-web.yaml`) dropped `SSH_PRIVATE_KEY` and `EC2_PUBLIC_IP` secrets entirely and assumes `github-oidc-role` via `aws-actions/configure-aws-credentials`. No new IAM was needed — that role already had `ssm:SendCommand`/`ssm:GetCommandInvocation` from the Packer build permissions.

## A stale assumption caught along the way

The original scripts targeted `haproxy` and `nginx`. Running the migrated script against the live instance failed immediately:

```
Failed to start nginx.service: Unit nginx.service not found.
```

`nginx` never existed on the current AMI — the live provisioning path (`infra/packer/ops/scripts/hardening.sh`) only enables `docker` and `haproxy`. Every `nginx` reference in the repo lived in `infra/packer/ops/bak/`, an old pre-Docker architecture that was never cleaned up. Fixed by swapping `nginx` → `docker` in the new script, and deleted `bak/` (38 files) after confirming zero references anywhere in the repo.

One operational note worth remembering: `docker.service` is a single systemd unit backing every container on the box. `manage-web.sh stop`/`upgrade` therefore bounces the whole container tier at once (Hugo, API, whatever else is running), not just "the web server" — confirmed live via the `docker.service` status output showing multiple container proxies under one PID. Per-service control still exists separately via `platform restart <service>`.

## Result

- Zero long-lived credentials in `manage-web.yaml`
- Targeting survives instance replacement with no manual updates
- Old scripts preserved in `scripts/legacy/` via `git mv` (history intact)
- Confirmed live: `start` action returned `Status: Success` with HAProxy logs showing real traffic flowing through immediately after
