---
title: "AWS Cost Audit: Surplus CPU Credits, Orphaned AMIs, and a Terraform-Managed Leftover Secret"
date: 2026-10-25
description: "Session writeup: why the AWS bill read higher, what was actually driving EC2 Other, cleanup of five legacy AMIs and snapshots, a new cost-hygiene script, a hardened Packer AMI prune, and removing a leftover Secrets Manager secret through Terraform."
tags: ["aws", "cost", "ebs", "snapshots", "ami", "packer", "cloudwatch", "t3", "terraform", "secrets-manager", "finops", "runbook"]
categories: ["infrastructure"]
summary: "The bill was not climbing steadily. A three-day t3 surplus-credit spike (~$1.63) and five orphaned legacy AMIs (~$1.00-1.40/month in snapshots) explained the increase. Both addressed, plus a leftover Terraform-managed secret removed with a targeted apply. Remaining cost is mostly fixed."
---

## Problem

`check-bill.sh` for 2026-09-22 to 2026-10-24 showed **$14.64** against $12.31 for September, and the question was whether the bill was trending up and where to cut.

| Service | Cost (USD) |
|---|---|
| EC2 - Other | 4.74 |
| EC2 Compute | 4.55 |
| VPC | 3.74 |
| Route 53 | 1.07 |
| Secrets Manager | 0.41 |
| ECR / S3 / Cost Explorer / SSM / CloudFront | 0.13 |

Two caveats before reading anything into the trend: the window is a rolling 32 days (not a calendar month), and the Cost Explorer line had dropped from ~$0.39 to $0.02, which masks movement elsewhere.

## Approach

### 1. Break down EC2 - Other by usage type

```bash
cd ~/cicd/platform-foundation/infra/infra_audit/cli
python infra_audit_cli.py bill --days 32 --by USAGE_TYPE --filter-service "EC2 - Other"
```

| Usage type | Cost (USD) | What it is |
|---|---|---|
| EBS:SnapshotUsage | 1.95 | AMI snapshots, including five orphans |
| CPUCredits:t3 | 1.62 | t3 surplus (unlimited-mode) credits |
| EBS:VolumeUsage.gp3 | 1.17 | The two live volumes (10 GiB + 4 GiB) |
| DataTransfer-Regional-Bytes | 0.11 | Noise |

(Total $4.84 here vs $4.74 in the service view because this window starts one day earlier.)

### 2. Snapshots: why seven existed

Every Packer build calls `CreateImage`, producing an AMI plus an 8 GiB snapshot. The prune post-processor in `infra/packer/ops/template.pkr.hcl` only matches the current name pattern (`ops-platform-observability-*`), so AMIs from earlier naming schemes were never cleaned up. Five legacy AMIs remained (Oct 2025 to Feb 2026):

| AMI | Name | Created |
|---|---|---|
| `ami-0fdb3d1c4f3920d1c` | `onwuachi-webserver-1761770878` | 2025-10-29 |
| `ami-0afe7e5241658172f` | `node-api-ami-1763289545` | 2025-11-16 |
| `ami-0e1169ab432d16ee5` | `admin-ui-ami-1763418812` | 2025-11-17 |
| `ami-0ce8904dc6bf46082` | `ops-haproxy-static-nginx-hugo-1771079086` | 2026-02-14 |
| `ami-001366d3e07f91842` | `ops-haproxy-static-nginx-hugo-1771160164` | 2026-02-15 |

The two Aug 30 AMIs were kept: `ami-04a3230110dce68f5` (SSM `/devopslab/ami/ops/latest`) and `ami-09bf85f3edd43931e` (the one `ops-01` is currently running on).

Upper bound for the five legacy snapshots: 40 GiB x $0.05 = $2.00/month. Standard snapshots bill on used blocks, so the real figure is lower.

### 3. Surplus CPU credits

A t3.micro defaults to unlimited mode, so sustained CPU above baseline is billed. Checked whether it was steady or a one-off:

```bash
aws cloudwatch get-metric-statistics --namespace AWS/EC2 \
  --metric-name CPUSurplusCreditsCharged \
  --dimensions Name=InstanceId,Value=<ops-01 instance id> \
  --start-time "$(date -u -d '14 days ago' +%FT%TZ)" --end-time "$(date -u +%FT%TZ)" \
  --period 86400 --statistics Sum
```

Result: **1,951.9 credits**, all in the daily buckets starting Oct 9, 10, and 11, and zero every day since Oct 12. At 60 credits per vCPU-hour and $0.05 per vCPU-hour, that is **$1.63**, matching the $1.62 line item. It was a one-time event, not a steady-state cost, so switching the instance to standard credit mode was not warranted. The cause of the Oct 9-11 CPU load has not been identified.

### 4. Leftover Secrets Manager secret

`aws secretsmanager list-secrets` showed one secret: `devopslab-mongodb-uri`, `LastAccessedDate: None`, last changed 2025-11-01. A repo search before deleting anything:

```bash
git grep -nE "mongodb-uri|aws_secretsmanager|secretsmanager:" -- .
```

found that it is **Terraform-managed** (`resource "aws_secretsmanager_secret" "mongodb"` in `infra/shared/secrets.tf`), with no live consumers (the only other references were commented-out outputs and an IAM permission that does not name the secret). Deleting it with `aws secretsmanager delete-secret` would have left Terraform state pointing at a deleted secret, so it was removed through Terraform instead.

**Gotcha: plan from the right root.** Running `terraform plan` inside `infra/shared` returned `Plan: 27 to add, 0 to destroy`. That is not a real plan: `infra/shared` is a child module (`infra/main.tf` calls `source = "./shared"`), so Terraform saw empty local state and wanted to build a whole VPC. The real root is `infra/`, which holds the S3 backend (`infra/backend.tf`) and takes `-var-file=environments/<env>.tfvars`. In that root the secret's address is `module.shared.aws_secretsmanager_secret.mongodb`. Never apply from `infra/shared`.

**Gotcha: the full plan is not just this change.** A full plan from `infra/` before the removal showed `7 to add, 3 to change, 5 to destroy`, which is a pending rollout that was never applied:

| Action | Resources |
|---|---|
| Replace | `module.ops.aws_instance.ops`, `aws_eip_association.ops`, `aws_route53_record.root`, `aws_route53_record.www` |
| Create | CloudWatch alarm `ops_status_check`, SNS topic `platform_alerts`, SNS email subscription |
| Update in place | Security groups `ops_sg`, `web_sg`, `wordpress_sg` |
| Destroy | `module.shared.aws_secretsmanager_secret.mongodb` |

The instance replacement is the AMI rollout (`ops-01` still runs `ami-09bf…` while SSM points to `ami-04a3…`). Applying everything would rebuild `ops-01` and recreate DNS records, with an outage, so the secret removal was isolated with `-target`.

## Result

### AMI and snapshot cleanup

`./scripts/cost-hygiene.sh audit` listed the five legacy AMIs as REMOVE and both Aug 30 AMIs as KEEP, with no unreferenced snapshots. `cleanup` then deregistered the five AMIs and deleted their five snapshots. Verified afterward with `infra_audit_cli.py snapshots`: only `snap-030dd2e4e074755a4` and `snap-0006e27127ef287a1` remain (16 GiB total).

### Packer prune changes

Three behaviors changed in the last post-processor (the AMI and the SSM parameter are already written by the time it runs):

1. Deletes **every** snapshot of a pruned AMI (`BlockDeviceMappings[]`), not just index `[0]`.
2. Skips any AMI used by a pending/running/stopping/stopped instance, preserving the rollback target.
3. Fails closed: if `describe-instances` errors, it logs a WARN and prunes nothing, exiting 0.

The generated shell was tested under `sh -e` (dash, the same shell Packer uses) against a mock `aws` CLI: multi-snapshot AMI fully removed, in-use AMI kept, instance-listing failure deletes nothing, and nothing happens when the AMI count is within `ami_keep_last`. `packer validate -syntax-only` passed on the real file.

### Secret removal

Removed `infra/shared/secrets.tf` and the three commented `mongodb_secret_arn` output lines in `infra/shared/outputs.tf`, then applied only that change:

```bash
cd ~/cicd/<worktree>/infra
terraform plan -input=false -var-file=environments/dev.tfvars \
  -target=module.shared.aws_secretsmanager_secret.mongodb -out=/tmp/rm-mongodb-targeted.tfplan
terraform show -no-color /tmp/rm-mongodb-targeted.tfplan | grep -E '^Plan:|^  # '   # expect 0 add, 0 change, 1 destroy
terraform apply "/tmp/rm-mongodb-targeted.tfplan"
```

Plan was `0 to add, 0 to change, 1 to destroy`; apply reported `0 added, 0 changed, 1 destroyed`. A saved plan applies exactly what it contains, which is why it was used instead of a bare `apply -target`. Afterward `list-secrets --include-planned-deletion` shows the secret with `DeletedDate` equal to the time of the apply (the field records when deletion was requested, not when it completes), and a fresh full plan returned to `7 to add, 3 to change, 4 to destroy`, one fewer destroy than before. The resource set no `recovery_window_in_days`, so the provider default of 30 days applies, putting the final purge around Nov 24.

### Commits

| Change | Branch | Commit |
|---|---|---|
| `scripts/cost-hygiene.sh` | `infra/cost-hygiene-script` | `5da7e2c` |
| Packer prune hardening | `infra/packer-prune-hardening` | `c1fee4d` |
| Remove mongodb secret (`secrets.tf`) | `infra/remove-mongodb-secret` | `1aff1c9` |
| Drop commented mongodb output | `infra/remove-mongodb-secret` | `22dd674` |

### Expected cost after changes (estimate, not yet measured)

| Item | Effect |
|---|---|
| Legacy snapshots removed | about -$1.00 to -$1.40/month |
| Surplus credits | $1.62 absent from future windows unless the CPU event recurs |
| Secrets Manager secret removed | up to -$0.41/month; how a secret in its recovery window bills was not verified |
| Estimated steady state | about $11 to $12 per 30 days |

## Verification still pending

- Merge the `infra/remove-mongodb-secret` PR. The apply already happened from the branch, and until the merge `main` still declares the secret, so a plan from `main` would try to recreate it (and fail while the old one is pending deletion). Nothing triggers on merge.
- Merge the Packer PR. Merging triggers `packer-build.yml`; in the build log, the prune step should show `Keeping ami-09bf85f3edd43931e (used by an instance)` and delete nothing, because `ops-01` still runs that AMI until the rollout.
- Check the Secrets Manager line on the bill in a few weeks, and confirm the secret is gone after about Nov 24.
- Re-check cost in a week with `./scripts/check-bill.sh 7`; a rolling 32-day window will keep blending old and new costs until then.

## Remaining and fixed costs

- **VPC $3.74** is consistent with one public IPv4 address (`$0.005/hr` for about 750 hours, billed even while the instance is stopped). Not yet confirmed by usage type.
- **Route 53 $1.07** is consistent with two hosted zones at $0.50 each plus queries. Not yet confirmed.
- **EC2 Compute $4.55** is roughly 437 instance-hours, or about 14 hours/day with the nightly stop workflow.

## Workflow findings (`terraform-deploy.yml`)

Observed while working out how to apply safely; none of this was changed:

- It is `workflow_dispatch` only, so nothing runs on merge.
- It runs `terraform plan -out=tfplan` and `terraform apply -auto-approve tfplan` in a single job, with no review step between them. For `dev` and `uat` the `approve` input is not even checked, so one dispatch applies the full pending rollout above.
- It pins Terraform 1.6.0, but `terraform state pull` showed the S3 state was last written by 1.12.2. Terraform refuses to read state written by a newer version, so the workflow's plan step is likely already failing. Not confirmed; the last run in the Actions tab will say. (A local attempt with a 1.6.0 binary failed at `init` with "Backend configuration changed" and changed nothing; `-reconfigure` and `-migrate-state` were deliberately not used.)

## Follow-ups

1. Review and apply the pending rollout on its own schedule: read the full plan first (including the SG changes, which show SSH ingress rule differences on `wordpress-sg` and in-place updates to `ops_sg` and `web_sg` that were not examined in detail), expect an `ops-01` rebuild and DNS recreation, and confirm the SNS email subscription afterward.
2. Bump `terraform_version` in `terraform-deploy.yml` to match the state, and consider splitting plan and apply with a review gate. Own infra PR, before using the workflow for the rollout.
3. Confirm VPC and Route 53 composition: `infra_audit_cli.py bill --by USAGE_TYPE --filter-service "Amazon Virtual Private Cloud"`.
4. Find the cause of the Oct 9-11 CPU event (Grafana Node Exporter Full for those dates, if Prometheus retention reaches that far).
5. Optional: make the prune rename-proof by tagging AMIs (for example `PackerFamily=ops`) and filtering on the tag instead of the name. This needs `ec2:CreateTags` on `github-oidc-role` (not verified) and a one-time manual tagging of the existing AMIs before the first tagged build. Until then, `cost-hygiene.sh audit` is the name-agnostic safety net.
6. Optional: tighten the `secretsmanager:*` permissions in `infra/shared/iam_github.tf` (it still grants create/delete/put to a secret that no longer exists), as a separate least-privilege PR.

## Quick reference

```bash
./scripts/check-bill.sh 32                                        # cost by service
cd infra/infra_audit/cli && python infra_audit_cli.py bill --days 32 --by USAGE_TYPE --filter-service "EC2 - Other"
./scripts/cost-hygiene.sh credits 14                              # surplus-credit charges
./scripts/cost-hygiene.sh audit                                   # dry run: KEEP / REMOVE
./scripts/cost-hygiene.sh cleanup                                 # confirm, then delete
aws secretsmanager list-secrets --include-planned-deletion \
  --query 'SecretList[].[Name,DeletedDate]' --output table        # secrets incl. pending deletion
terraform plan -input=false -var-file=environments/dev.tfvars     # from infra/, never infra/shared
```
