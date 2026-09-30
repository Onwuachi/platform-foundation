---
title: "SSM Automation Documents: Codifying Multi-Step Runbooks"
date: 2026-09-30
description: "Building and running AWS Systems Manager Automation documents that chain instance-level commands with direct AWS API calls, using outputs from one step as inputs to the next."
tags: ["aws", "ssm", "systems-manager", "automation", "runbooks", "devops-pro", "dop-c02"]
categories: ["AWS", "DevOps Pro"]
summary: "SSM Automation documents orchestrate multi-step, auditable runbooks that mix EC2-level commands with control-plane API calls — the backbone of auto-remediation and incident response tooling."
---

## Why This Matters (DOP-C02 Domain 5.2)

Automation documents are how AWS turns "run these 8 steps in order, in the right sequence, with the right error handling" into something repeatable and unattended. This underpins:

- **AWS Config auto-remediation** — non-compliant resource triggers an Automation document to fix it
- **EventBridge-triggered response** — an alarm or event fires an Automation runbook
- **Patch Manager** — `AWS-RunPatchBaseline` is itself an Automation document under the hood
- **Incident response runbooks** — the whole point of Domain 5, codified and auditable

## Automation vs. Command Documents (Exam-Critical Distinction)

| | Command Document (`AWS-RunShellScript`) | Automation Document |
|---|---|---|
| Scope | Runs on instance(s) only | Can span instances AND direct AWS API calls |
| Steps | Single action | Multi-step, can branch/approve/wait |
| Data passing | No built-in step chaining | `outputs` + `Selector` pass data between steps |
| Typical trigger | Human or script, one-off | EventBridge, Config, Incident Manager, human |
| Requires `assumeRole`? | No | Required for unattended/service-triggered execution; optional for interactive |

## Lab: Build a Two-Step Automation Document

Goal: check disk usage on an instance via `aws:runCommand`, then tag the instance based on that result via `aws:executeAwsApi` — demonstrating both instance-level execution and direct control-plane calls in a single document, chained together.

```bash
cat > dop-lab-automation-diskcheck.yaml << 'EOF'
schemaVersion: '0.3'
description: 'DOP-C02 Lab 5.2 - Check disk space, tag instance if healthy'
assumeRole: ''
parameters:
  InstanceId:
    type: String
    description: 'Target instance ID'
mainSteps:
  - name: CheckDiskSpace
    action: 'aws:runCommand'
    inputs:
      DocumentName: AWS-RunShellScript
      InstanceIds:
        - '{{ InstanceId }}'
      Parameters:
        commands:
          - 'df -h / | awk ''NR==2{print $5}'' | tr -d ''%'''
    outputs:
      - Name: DiskUsedPercent
        Selector: '$.Output'
        Type: String

  - name: TagIfHealthy
    action: 'aws:executeAwsApi'
    inputs:
      Service: ec2
      Api: CreateTags
      Resources:
        - '{{ InstanceId }}'
      Tags:
        - Key: LastHealthCheck
          Value: 'passed-{{ global:DATE_TIME }}'
EOF
```

Register it:

```bash
aws ssm create-document \
  --profile platform-foundation --region us-east-1 \
  --name "dop-lab-diskcheck" \
  --document-type "Automation" \
  --document-format YAML \
  --content file://dop-lab-automation-diskcheck.yaml
```

Run it against a target instance:

```bash
aws ssm start-automation-execution \
  --profile platform-foundation --region us-east-1 \
  --document-name "dop-lab-diskcheck" \
  --parameters "InstanceId=<INSTANCE_ID>"
```

Check status:

```bash
aws ssm get-automation-execution \
  --profile platform-foundation --region us-east-1 \
  --automation-execution-id <EXECUTION_ID> \
  --query "AutomationExecution.[AutomationExecutionStatus,CurrentStepName]" \
  --output table
```

Inspect per-step outputs (this is where you see the chained data):

```bash
aws ssm get-automation-execution \
  --profile platform-foundation --region us-east-1 \
  --automation-execution-id <EXECUTION_ID> \
  --query "AutomationExecution.StepExecutions[].[StepName,StepStatus,Outputs]" \
  --output json
```

Verify the tag was actually applied:

```bash
aws ec2 describe-tags \
  --profile platform-foundation --region us-east-1 \
  --filters "Name=resource-id,Values=<INSTANCE_ID>" "Name=key,Values=LastHealthCheck" \
  --output table
```

## What the Step Chaining Actually Does

`CheckDiskSpace` captures the shell command's stdout, exposes it as `DiskUsedPercent` via a JSONPath `Selector` (`$.Output`) against the command result. Nothing in `TagIfHealthy` consumes `DiskUsedPercent` directly in this minimal example, but the same mechanism (`{{ CheckDiskSpace.DiskUsedPercent }}`) is how you'd reference it in a later step — e.g., branching (`aws:branch`) on whether the value exceeds a threshold before deciding whether to tag, alert, or remediate.

## Common Failure Mode: Stale/Terminated Target Instance

If the target `InstanceId` no longer exists or is stopped, the execution will sit in `InProgress` on the `aws:runCommand` step and eventually report `TimedOut` — not an immediate error. Always confirm the instance is actually running and SSM-managed before troubleshooting IAM permissions:

```bash
aws ec2 describe-instances \
  --profile platform-foundation --region us-east-1 \
  --instance-ids <INSTANCE_ID> \
  --query "Reservations[].Instances[].[InstanceId,State.Name]" \
  --output table
```

## $0-Cost Note

No charge for Automation executions themselves. `aws:runCommand` steps incur no extra charge beyond the running instance. `aws:executeAwsApi` steps are free API calls. Total lab cost is just the underlying EC2 instance's normal running cost for the duration of the test.
