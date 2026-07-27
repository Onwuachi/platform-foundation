---
title: "Platform Foundation: DR & IAM Hardening Session"
date: 2026-07-23
description: "Audit and remediation of backup credentials, S3 lifecycle, and node-loss recovery testing"
tags: [aws, iam, terraform, disaster-recovery, s3, security]
categories: [infrastructure]
summary: "Retired a static admin credential in favor of scoped OIDC, fixed unbounded S3 snapshot growth, and ran a real node-loss recovery test with measured timing instead of an unvalidated claim."
---

## Why this happened

OPERATIONS.md claimed "zero manual steps" for full node loss recovery. That
claim had never actually been tested end-to-end — it was inferred from the
architecture, not measured. Before reusing that line anywhere external
(resume, interviews), it needed to either be validated or corrected. That
question opened up three more, in order: what's actually backing up the
backup, who has permission to touch it, and is that permission scoped
correctly.

## What was found

**1. The nightly backup job ran as an IAM user with `AdministratorAccess`,
using static, long-lived access keys stored in a GitHub secret.**

`platform-state-backup.yml` used `aws-access-key-id` /
`aws-secret-access-key` from GitHub secrets, authenticating as
`serverless-admin` — an IAM user with full account admin rights, no MFA,
created March 2025. A job that only needs to read one bucket and write to
another had account-wide delete/create/modify access on everything,
including IAM itself. If that GitHub secret had ever leaked, or the
workflow file had been tampered with, the blast radius was the entire AWS
account.

**2. The backup S3 bucket had no lifecycle rule expiring old snapshots.**

Nightly snapshots (`snapshots/YYYY-MM-DD/`) had been accumulating since
May 9 with nothing pruning them — the one existing lifecycle rule only
handled delete markers and abandoned multipart uploads, not the actual
dated snapshot objects. Versioning is also enabled on both buckets, which
meant the live `platform/` state prefix was silently retaining every
historical version of every overwritten file (config maps, service
registries) with the same problem.

**3. Full node-loss recovery had never actually been executed as a test —
only assumed from the architecture.**

## What was fixed

**Backup job credentials — replaced static admin key with scoped OIDC.**

Added `github_backup_role` (Terraform, `infra/shared/iam_github.tf`) using
the same GitHub OIDC provider already in use for the Packer build role.
Attached policy grants only:
- `s3:GetObject` / `s3:ListBucket` on the primary bucket (read-only)
- `s3:PutObject` / `s3:ListBucket` on the backup bucket (write-only, no
  delete)

Updated the workflow to `role-to-assume` instead of static keys, and added
the `permissions: id-token: write` block the workflow was missing (without
it, GitHub never issues an OIDC token and the credentials step fails —
caught this on the first real test run, fixed, re-ran, confirmed green).

Retired the old `serverless-admin` access key. Rotated a new one for
remaining local CLI use since the account's only IAM user was, until now,
also being used for interactive `aws` commands from the workstation —
worth separating those uses going forward.

**S3 lifecycle — added expiration rules to the backup bucket** without
touching the existing `cleanup-old-versions` rule:
- `snapshots/` prefix: expire after 14 days, noncurrent versions after 7
- (Live `platform/` prefix noncurrent-version trimming was considered but
  applied to the wrong bucket on the first pass — see Corrections below.)

**Deliberate design decision, confirmed not a gap**: the backup bucket is
intentionally *not* Terraform-managed, so a `terraform destroy` (or a bad
apply) against the primary infrastructure can't reach it. This is the same
logic as an air-gapped backup — isolating the DR copy from the control
plane that can destroy the primary. Verified this isolation is also true
at the IAM level (the new backup role has no delete permission on either
bucket) — the isolation isn't just "not in Terraform state," it's actually
enforced by policy.

## Recovery test — executed, not assumed

Terminated the running instance (`i-048fc0d2abaa5e472`) directly, deliberately
simulating real node loss rather than a planned teardown.

| Milestone | Time (UTC) |
|---|---|
| Instance terminated | 22:44:06 |
| `tapply` run, new instance launched | 22:55:02 |
| Rehydrate complete (config render, cert renewal, service start) | ~22:56 |
| Confirmed healthy — site, correct content, HAProxy auth | 23:00:09 |

**Result**: recovery is manually triggered by design (a single `tapply`
command) — no auto-healing exists, and this is intentional: it preserves
the ability to terminate an instance for debugging without the platform
immediately fighting back by respawning it. Once triggered, Terraform
recreates the instance and re-associates the Elastic IP in under 20
seconds. The `platform-rehydrate` bootstrap — S3 state sync, HAProxy config
render and validation, TLS certificate renewal, container pull and
start — completes within roughly one minute of boot.

Validated via the actual `/var/log/ops-user-data.log` output on the new
instance, not just an HTTP 200: rehydrate ran the S3 sync, HAProxy auth
credential injection, certbot renewal, config validation (twice — mid-render
and final), and service start in sequence with proper retry/wait logic for
S3 and Docker readiness, and completed without error.

## Corrections made along the way

Worth keeping in the writeup rather than smoothing over, since the
discipline of catching these mid-session is part of what made the test
trustworthy:

- Initially flagged a committed `.venv/` directory in `infra_audit` as a
  git hygiene issue. It wasn't — `.gitignore` already covered it; the
  zip export just included local untracked files. Corrected before any
  unnecessary cleanup work.
- Wrote an S3 lifecycle rule targeting `platform/` prefix on the **backup**
  bucket, based on an assumption about where live state lived. The
  `list-object-versions` check came back empty, which caught the mistake —
  live `platform/` state is in the **primary** bucket, not backup. The
  rule is harmless (matches nothing) but not useful as written.
- Suggested importing the backup bucket into Terraform for consistency.
  Wrong call — the whole point was keeping it outside the blast radius of
  `terraform destroy`. Reversed that recommendation once the reasoning was
  explained.
- A routine IAM apply unexpectedly destroyed and recreated the running
  production instance. Root cause: `data.aws_ssm_parameter.ops_ami` always
  reads the *latest* value from SSM on every plan/apply, so any Packer
  build since the last apply forces instance replacement on the next
  apply — even one only touching unrelated IAM resources. Still open (see
  below).
- A stale terminal session had `serverless-admin`'s access key deleted
  while it was also the credential the local CLI was authenticated with —
  briefly lost local `aws` CLI access mid-session. Recovered via AWS
  Console (separate from IAM user credentials) by issuing a fresh access
  key. No account-level lockout; would recommend a second break-glass
  credential going forward given this account currently has exactly one
  IAM user.
- First claimed a `curl -u derrick:... onwua.com/projects/` check
  validated HAProxy auth on the rebuilt instance. It didn't — that path is
  served by CloudFront + S3 from a separate, unrelated Terraform project,
  and returned 200 regardless of credentials passed. The `onwuachi.com`
  check (serving from `nginx`) was the actual validation of the rebuilt
  instance.

## Still open

1. **S3-primary-loss recovery has no tested or scripted path.** If
   `platform-api-services` itself is lost (not just the EC2 instance),
   there is currently no automated restore from
   `platform-api-services-backup/snapshots/` back into primary. This is
   the gap the original "zero manual steps" claim didn't account for —
   that claim was only ever true for EC2 loss with S3 intact.
2. **AMI-to-instance coupling via SSM "latest" parameter** causes
   unrelated `apply` runs to force-replace the production instance. Worth
   deciding whether to keep "always latest" behavior (consistent with the
   immutable-infra philosophy, but couples unrelated changes together) or
   pin the AMI explicitly and promote it as a deliberate step.
3. **20 high-severity Dependabot vulnerabilities** flagged on push,
   unreviewed.
4. **Branch protection on `main` requires PRs, but direct pushes are
   currently being bypassed** — worth a deliberate decision either way
   rather than leaving it inconsistent.
5. **`serverless-admin` still has `AdministratorAccess` and no MFA
   assigned** (MFA setup was surfaced during the credential-recovery
   detour but not yet completed).
6. **No documented, versioned procedure for rebuilding the backup bucket
   itself from nothing** — deliberately outside Terraform, but that means
   its exact configuration (versioning, encryption, lifecycle, bucket
   policy) currently only exists as tribal knowledge.
