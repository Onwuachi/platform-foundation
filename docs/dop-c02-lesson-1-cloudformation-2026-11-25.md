---
title: "DOP-C02 Lesson 1: CloudFormation hands-on lab"
date: 2026-11-25
description: "Hands-on CloudFormation lab for DOP-C02: nested stacks, change sets, drift, rollback, a Lambda-backed custom resource, and self-managed StackSets in one account."
tags:
  - aws
  - cloudformation
  - dop-c02
  - stacksets
  - drift-detection
  - custom-resources
  - training
categories:
  - Infrastructure
summary: "One root stack with three nested stacks plus a two-region StackSet, used to see change sets, drift, rollbacks and custom resources in action, with scripted teardown and recreate."
---

# Problem

DOP-C02 asks a lot about CloudFormation behavior (change sets, drift, rollback
states, custom resources, StackSets). Reading about it was not enough. Goal:
see each behavior happen in a real account, cheaply, with everything
destroyable and recreatable from git.

---

# Approach

Spec lives in `labs/dop-c02/` on branch `infra/dop-lab-cfn`:

```
labs/dop-c02/
  cfn/root.yaml            root stack, nests the three below
  cfn/nested/storage.yaml  S3 bucket, DynamoDB table (PITR on)
  cfn/nested/iam.yaml      Lambda execution role
  cfn/nested/custom.yaml   Lambda-backed custom resource + log group
  cfn/stackset/            roles.yaml, marker.yaml
  scripts/                 lab-up.sh, lab-down.sh, stackset-up.sh, ss-wait.sh
```

Everything is tagged `Project=dop-lab`. Region: us-east-1 (StackSet instances
also in us-east-2).

## Terraform to CloudFormation mapping

| Terraform | CloudFormation |
|---|---|
| `plan -out` | `deploy --no-execute-changeset` |
| read the plan | `describe-change-set` |
| `apply plan` | `execute-change-set` |
| `destroy` | `delete-stack` |
| state file plus lock | the stack itself (no backend needed) |
| modules | nested stacks |
| multi-account/region fan-out | StackSets |

## What each lab showed

1. **Nested stacks and change sets.** `package` uploads nested templates to S3
   and rewrites `TemplateURL`. A root change set lists every nested stack as
   `Modify`, even when nothing inside changed. Use `--include-nested-stacks`
   on `create-change-set` to see inside.
2. **Drift.** Disabled PITR by hand, drift check showed `MODIFIED` with
   `ExpectedValue` vs `ActualValue`. Drift only covers properties set in the
   template. CloudFormation does not auto-repair drift; fix by hand, change
   the template, or use the Config rule `cloudformation-stack-drift-detection-check`
   with remediation. Redeploying an unchanged template does not repair drift
   (documented behavior, not separately tested here).
3. **Rollback.** Reusing an existing bucket name failed at validation before
   any resource was touched. Root ended `UPDATE_ROLLBACK_COMPLETE`, a stable
   state you can update again. Failed create ends `ROLLBACK_COMPLETE` (delete
   and recreate). `UPDATE_ROLLBACK_FAILED` needs `ContinueUpdateRollback`
   (explained, not triggered).
4. **Custom resource.** Lambda must answer the pre-signed `ResponseURL` with
   SUCCESS or FAILED (`cfn-response`, inline `ZipFile` only). No response
   means a hang of about an hour. `Delete` must succeed or the stack goes
   `DELETE_FAILED`. The Lambda's own `reason` string appears in the events,
   and rollback re-invokes the Lambda with the old properties. Explicit log
   group with 3-day retention so teardown removes it.
5. **StackSets (SELF_MANAGED).** Needs two fixed-name roles, so deploy with
   `CAPABILITY_NAMED_IAM`. A stack set exists only in the administrator
   region; instances are ordinary stacks named `StackSet-<name>-<uuid>` in each
   target region. Creating a stack set deploys nothing until you add
   instances. Operation preferences (`RegionOrder`, `FailureToleranceCount`,
   `MaxConcurrentCount`) control rollout order and blast radius.

---

# Result

All five labs worked. Update fan-out confirmed: SSM parameter at version 2 in
both regions.

## Verification

```bash
aws cloudformation describe-stacks --stack-name dop-lab-root \
  --query 'Stacks[0].StackStatus' --output text        # UPDATE_COMPLETE
aws cloudformation list-stack-instances --stack-set-name dop-lab-marker \
  --query 'Summaries[].[Region,Status]' --output table # both CURRENT
for R in us-east-1 us-east-2; do
  aws ssm get-parameter --name /dop-lab/stackset/marker --region $R \
    --query 'Parameter.[Value,Version]' --output text
done
```

## Run and tear down

```bash
./labs/dop-c02/scripts/lab-up.sh
./labs/dop-c02/scripts/stackset-up.sh
./labs/dop-c02/scripts/lab-down.sh   # instances, then stack set, then roles, then root
```

Teardown order matters: delete StackSet instances before the stack set, and
the roles stack last, or the stack set cannot assume its roles.

## Cost

Idle cost is effectively zero (Lambda, IAM, SSM standard parameters free;
on-demand DynamoDB and tiny buckets). The execution role has
`AdministratorAccess` because this is a lab account setup; delete with the
roles stack.

## Not covered yet

StackSet failure-tolerance demo, `CreationPolicy`/`cfn-signal`, stack
policies, `DeletionPolicy: Retain`/`Snapshot`, `ContinueUpdateRollback`.

# Related

- Next: Lesson 2, CI/CD (CodePipeline, CodeBuild `buildspec.yml`, CodeDeploy `appspec.yml`)
