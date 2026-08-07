+++
title = "AWS Auto Scaling Groups: The Self-Healing Control Loop"
date = "2026-08-07"
description = "How Auto Scaling Groups continuously reconcile desired vs current capacity, proven with a live termination-and-replace lab in devopslab-vpc."
tags = ["aws", "asg", "auto-scaling", "self-healing", "dop-c02", "ec2"]
categories = ["aws", "dop-c02"]
summary = "A hands-on walkthrough of how ASG's control loop detects instance failure and automatically replaces it, using a live lab in devopslab-vpc."
draft = false
type = "kb-article"
weight = 0
+++

# Overview

An Auto Scaling Group (ASG) is not primarily a scaling tool — it is a control loop. Its core job is to continuously compare desired capacity against current capacity and reconcile any difference by launching or terminating instances. This article covers the mechanics, a live lab proving self-healing behavior, and a DR/resilience test runbook you can repeat against any ASG.

<!--more-->

# Why It Matters

Instance failure is inevitable — hardware faults, kernel panics, bad deploys, or accidental termination. Without a control loop watching capacity, recovery means someone gets paged and manually launches a replacement. With an ASG, the platform detects and fixes it automatically, often before anyone else sees the failure. This is the foundation for every resilience pattern in AWS.

---

# Where It Fits

DOP-C02 Domain 3 — Resilient Cloud Solutions

Launch Template
|
v
Auto Scaling Group <-- continuously enforces Desired Capacity
|
v
EC2 Instance(s)


ASG is the foundation. Lifecycle hooks, ELB health checks, Instance Refresh, and multi-AZ HA all extend this same reconciliation loop.

---

# The Big Picture

Desired = 1, Current = 1 <- steady state
Instance dies -> Current = 0 <- failure event
ASG detects Current < Desired <- reconciliation triggers
ASG launches replacement <- from Launch Template
Current = 1 <- steady state restored


No human, no Lambda, no cron job. The control loop runs continuously.

---

# Core Concepts

**Launch Template** — the recipe for new instances: AMI, instance type, security groups, user data, IAM instance profile. Always preferred over the older Launch Configuration (versioned, supports mixed instance types).

**Desired / Min / Max capacity** — Desired is the live target the ASG enforces. Min/Max are guardrails. Scaling policies only ever modify Desired — the ASG loop does the actual launching and terminating.

**Health checks** — two types:
- `EC2` — instance status checks (is the VM reachable?)
- `ELB` — target group checks (is the app actually responding?)
Either type triggers termination and replacement when unhealthy.

**Instance Refresh** — rolling replacement of all instances when the Launch Template changes (e.g. new AMI baked by Packer), respecting a min-healthy-percentage threshold.

**Warm Pools** — pre-initialized stopped instances kept ready to reduce launch latency on scale-out. Advanced; exam-relevant but not needed for basic self-healing.

---

# Real-World Example

Live lab executed in `devopslab-vpc` (`vpc-041057f0cc0747a4e`), account `046685909731`, us-east-1.

**Resources built:**
- Security group `dop-lab-sg` (`sg-0e82c6115d4e21672`) — port 80 open, port 22 restricted to a single IP; isolated from production groups
- Launch Template `dop-lab-lt` (`lt-01c5e8fa702e42268`) — AL2023 AMI `ami-084b17e3cb2d02a6c`, t3.micro, user data installs/starts nginx
- ASG `dop-lab-asg` — min=1/max=1/desired=1 in public subnet `subnet-034dd9ac56c1aeb6b`, no ALB (deliberate — tests raw control loop)

**What happened:**
1. ASG launched `i-03e47c5d95948ffcd`, status `Healthy/InService`
2. Instance manually terminated
3. Within ~60 seconds ASG launched `i-0e9dfadba58d10dd8` — same Launch Template, no human intervention
4. ASG scaled to 0/0/0 after lab to stop billing; resources left in place for the next lab

---

# ASG Self-Healing / DR Test Runbook

Use this sequence to verify ASG self-healing behavior on any ASG — in devopslab for practice, or in a non-production environment for DR validation.

**Prerequisites:** AWS CLI configured, profile with EC2/autoscaling read+write permissions.

```bash
# 1. Confirm ASG steady state — note the current InstanceId
aws autoscaling describe-auto-scaling-groups \
  --profile platform-foundation \
  --auto-scaling-group-names <asg-name> \
  --query "AutoScalingGroups[0].Instances" \
  --output table

# 2. Terminate the running instance (simulates failure)
aws ec2 terminate-instances \
  --profile platform-foundation \
  --instance-ids <instance-id>

# 3. Poll until replacement appears (run repeatedly, ~30-60s)
aws autoscaling describe-auto-scaling-groups \
  --profile platform-foundation \
  --auto-scaling-group-names <asg-name> \
  --query "AutoScalingGroups[0].Instances" \
  --output table

# 4. Confirm new InstanceId is Healthy/InService
# Expected: different InstanceId, same InstanceType and LaunchTemplate version

# 5. Scale to zero when done (stops billing without deleting ASG)
aws autoscaling update-auto-scaling-group \
  --profile platform-foundation \
  --auto-scaling-group-name <asg-name> \
  --min-size 0 --max-size 0 --desired-capacity 0
```

**What a passing test looks like:**
- Old InstanceId disappears from the Instances list
- New InstanceId appears within ~60-90 seconds
- New instance shows `LifecycleState: InService` and `HealthStatus: Healthy`
- Launch Template ID and version match the original

**What a failing test reveals:**
- Instance stuck in `Pending` — likely user data error or security group blocking outbound (check Systems Manager Session Manager or instance console output)
- No replacement launched — check ASG activity history: `aws autoscaling describe-scaling-activities --auto-scaling-group-name <asg-name>`

---

# Engineering Analogy

Same reconciliation pattern as a Kubernetes Deployment enforcing replica count. The controller does not fix a crashed pod — it detects actual state differs from desired state and drives it back into alignment. ASG does the same thing one layer down, at the EC2 instance level.

Your current platform-foundation model (Terraform → EC2 → Docker → HAProxy) is instance-centric. ASG is the AWS-native shift to platform-managed capacity — the platform replaces the instance, not the engineer.

---

# Best Practices

- Always use Launch Templates, not Launch Configurations (versioned, supports mixed instance types)
- Create isolated security groups for lab/test environments — never reuse production SGs even if ports match
- Test the raw ASG loop without an ALB first — isolates the control loop from health check behavior
- Scale to 0/0/0 (not delete) when pausing a lab you will resume — saves rebuilding Launch Templates and ASGs
- Run the DR test runbook above against non-production ASGs periodically to verify self-healing is actually working

---

# Common Mistakes

- Assuming ASG restarts a failed instance — it does not. It terminates the unhealthy instance and launches a brand new one from the Launch Template. State on the old instance is gone.
- Reusing production security groups for throwaway labs — creates unnecessary blast radius risk
- Forgetting to scale to zero after a lab — t3.micro is cheap but it is not free
- Testing self-healing only at launch time and never again — the Launch Template or user data can drift, breaking the replacement path silently

---

# Pro Tip

> `describe-auto-scaling-groups` and all other read-only API calls are free — describe, list, get calls carry no AWS charge. Only running compute, storage, and data transfer cost money. Poll freely while observing ASG behavior. The cost discipline is remembering to scale to zero when done, not limiting how many times you check status.

---

# Key Takeaways

- ASG's job is continuous reconciliation of desired vs current capacity — scaling is a side effect of that, not the primary purpose
- Replacement always means a new instance from the Launch Template, not a restart of the old one
- This control loop is the foundation for lifecycle hooks, ELB-driven health checks, Instance Refresh, and every other Domain 3 resilience pattern
- The DR test runbook above can be reused against any ASG to verify self-healing is actually wired up correctly

---

# Related Articles

- aws-codepipeline-codebuild-codedeploy.md

---

# References

- AWS Documentation: Amazon EC2 Auto Scaling User Guide
- Live lab performed in devopslab-vpc, account 046685909731, 2026-08-07
- Command history: `history 55` output from devopslab CLI session
