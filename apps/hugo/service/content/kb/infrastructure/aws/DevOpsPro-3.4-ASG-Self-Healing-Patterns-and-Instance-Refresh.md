+++
title = "ASG Self-Healing Patterns and Instance Refresh"
date = "2026-08-08"
description = "How ASG composes with ELB health checks and Instance Refresh to create application-level self-healing and zero-downtime fleet rolling replacements."
tags = ["aws", "asg", "self-healing", "instance-refresh", "elb", "dop-c02"]
categories = ["aws", "dop-c02"]
summary = "The full self-healing loop: ELB health checks drive ASG replacement, and Instance Refresh rolls new AMIs fleet-wide without downtime — with a live lab and a real debugging case."
draft = false
type = "kb-article"
weight = 0
+++

# Overview

ASG self-healing is not a single feature — it is the composition of ELB health checks, ASG health check type, lifecycle hooks, and Instance Refresh working together. This article covers the full loop, how each piece contributes, and what breaks when one piece is misconfigured.

<!--more-->

# Why It Matters

EC2 health checks only detect VM failure. An application can crash while the instance stays running and passes EC2 checks — traffic keeps routing to a broken instance. ELB health checks close this gap. Instance Refresh closes the drift gap — ensuring the fleet always runs the current Launch Template version. Together they form a self-healing system that requires no human intervention for both failure recovery and fleet updates.

# Where It Fits

DOP-C02 Domain 3 — Resilient Cloud Solutions

Application failure detected by ALB
|
v
Target Group marks instance unhealthy
|
v
ASG (health-check-type: ELB) terminates instance
|
v
Lifecycle hook: Pending:Wait (bootstrap runs)
|
v
CONTINUE → InService → ALB registers target
|
v
Traffic restored — no human intervention


---

# The Big Picture

Two failure modes, two recovery paths:

VM failure:
EC2 check fails → ASG detects Current < Desired → replacement launches

App failure (VM healthy):
ELB check fails → Target Group unhealthy → ASG terminates → replacement launches
(only works when health-check-type = ELB)

Fleet drift (old AMI):
Instance Refresh → rolling replacement → MinHealthyPercentage maintained


---

# Core Concepts

**Health check type — the critical setting:**
- `EC2` (default) — replaces only on VM failure
- `ELB` — replaces on VM failure OR app failure
- Switch with: `aws autoscaling update-auto-scaling-group --health-check-type ELB`

**Health check grace period** — how long ASG waits after launch before starting ELB checks. Must be longer than your bootstrap time or healthy instances get terminated mid-startup.

**Instance Refresh** — rolls the entire fleet to a new Launch Template version:
- `MinHealthyPercentage` — floor of healthy instances maintained during rollout
- `InstanceWarmup` — how long ASG waits after a replacement before counting it healthy and moving to the next
- `AutoRollback` — reverts if CloudWatch alarms fire during refresh (exam-relevant)

**Orphaned ELB health check** — if health-check-type is ELB but no live Target Group/ALB is attached, all ASG activity stalls. Instances can never pass health checks, Instance Refresh hangs at 0%. Always audit after tearing down an ALB.

---

# Real-World Example

Live lab in `devopslab-vpc`, ASG `dop-lab-asg`:

**Instance Refresh — first attempt (failed):**
- Triggered refresh with `MinHealthyPercentage: 50, InstanceWarmup: 60`
- Stuck at 0% / InProgress for 11+ minutes
- Root cause: health-check-type was still ELB from 3.3 lab, but ALB had been deleted — Target Group `dop-lab-tg` was orphaned with no ALB behind it; lifecycle hook `dop-lab-launch-hook` still attached adding 120s delays per launch attempt
- Fix: deleted lifecycle hook, switched health-check-type to EC2, detached orphaned Target Group

**Instance Refresh — second attempt (successful):**
- Clean ASG: EC2 health checks, no hooks, no orphaned TGs
- Refresh with `MinHealthyPercentage: 50, InstanceWarmup: 30`
- Progressed: Pending → InProgress → 100% → Successful
- Scaled to 0/0/0 after completion

**Audit commands when ASG behavior is unexpected:**
```bash
# Check health check type and attached target groups
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-name <asg-name> \
  --query "AutoScalingGroups[0].{HealthCheckType:HealthCheckType,HealthCheckGracePeriod:HealthCheckGracePeriod,TargetGroupARNs:TargetGroupARNs}" \
  --output json

# Check lifecycle hooks
aws autoscaling describe-lifecycle-hooks \
  --auto-scaling-group-name <asg-name> \
  --output table

# Check active refreshes
aws autoscaling describe-instance-refreshes \
  --auto-scaling-group-name <asg-name> \
  --output table
```

---

# Engineering Analogy

Instance Refresh maps directly to your Packer + platform-foundation deploy workflow — you bake a new AMI, update the Launch Template, and need all running instances replaced with the new version. Without Instance Refresh you'd manually terminate instances and watch ASG replace them one by one. Instance Refresh automates that rolling replacement with a guaranteed minimum healthy percentage — equivalent to a zero-downtime deploy in your CI/CD pipeline.

---

# Best Practices

- Always switch to ELB health checks when an ALB/Target Group is attached — EC2 checks alone miss app-level failures
- Set grace period longer than your slowest bootstrap path — a short grace period terminates healthy instances mid-startup
- Audit ASG config (health check type, hooks, target groups) before running Instance Refresh
- Use `AutoRollback` with a CloudWatch alarm on Instance Refresh for production — automatically reverts if error rate spikes during rollout
- After tearing down an ALB in a lab or production, always detach the Target Group from the ASG and revert health-check-type to EC2

---

# Common Mistakes

- Leaving health-check-type as ELB after deleting the ALB — silently blocks all ASG activity
- Grace period shorter than bootstrap time — instances terminated before nginx/app finishes starting
- Running Instance Refresh with lifecycle hooks attached and a short HeartbeatTimeout — each replacement stalls for the full timeout duration, refresh takes hours
- Assuming Instance Refresh is instant — with `InstanceWarmup: 60` and 10 instances, minimum refresh time is 10+ minutes

---

# Pro Tip

> When Instance Refresh stalls at 0% / InProgress, the first thing to check is not the refresh itself — it's the ASG config. Orphaned ELB health checks and attached lifecycle hooks are the two most common blockers. Run the audit commands above before touching the refresh.

---

# Key Takeaways

- EC2 health checks = VM-level healing only; ELB health checks = application-level healing
- Orphaned ELB health check type (no live ALB) silently blocks all ASG activity including Instance Refresh
- Instance Refresh is the correct answer for "deploy new AMI to fleet without downtime" exam scenarios
- Always audit ASG config (health check type, hooks, target groups) when behavior is unexpected

---

# Related Articles

- DevOpsPro-AWS-Auto-Scaling-Groups-The-Self-Healing-Control-Loop.md
- DevOpsPro-ASG-Lifecycle-Hooks-Pending-Wait-and-Bootstrap-Control.md
- DevOpsPro-ALB-Target-Groups-and-ASG-Integration.md

---

# References

- AWS Documentation: Amazon EC2 Auto Scaling — Instance Refresh
- Live lab performed in devopslab-vpc, account 046685909731, 2026-08-08
