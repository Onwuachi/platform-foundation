+++
title = "ASG Lifecycle Hooks: Pending:Wait and Bootstrap Control"
date = "2026-08-08"
description = "How ASG lifecycle hooks pause instance launches and terminations to allow custom bootstrap logic, with a live lab observing Pending:Wait state."
tags = ["aws", "asg", "lifecycle-hooks", "auto-scaling", "dop-c02", "ec2"]
categories = ["aws", "dop-c02"]
summary = "Lifecycle hooks intercept ASG instance transitions — proven live by observing Pending:Wait and manually signaling CONTINUE, mirroring the Packer/systemd staged-start pattern."
draft = false
type = "kb-article"
weight = 0
+++

# Overview

ASG lifecycle hooks intercept instance state transitions — at launch or termination — and hold the instance in a `Waiting` state until your code signals completion or the timeout fires. Without hooks, instances enter `InService` immediately on launch regardless of whether your application is actually ready.

<!--more-->

# Why It Matters

A fleet that routes traffic to instances before bootstrap completes causes intermittent failures that are hard to debug. Lifecycle hooks give you a guaranteed window to finish bootstrap logic — pull secrets, register with monitoring, warm a cache, drain connections — before the instance enters or exits the traffic pool.

# Where It Fits

DOP-C02 Domain 3 — Resilient Cloud Solutions

EC2 Launch
|
v
Pending:Wait <-- lifecycle hook fires here
|
v
Your code runs (Lambda / SSM / script)
|
v
CONTINUE signal (or timeout fires DefaultResult)
|
v
InService


Termination hooks mirror this — `Terminating:Wait` before the instance is destroyed.

---

# The Big Picture

ASG Lifecycle Hook
|
+-- Transition: autoscaling:EC2_INSTANCE_LAUNCHING
+-- HeartbeatTimeout: 120s (your code must signal within this window)
+-- GlobalTimeout: 12000s (hard ceiling, even with heartbeat extensions)
+-- DefaultResult: CONTINUE (safe for labs) | ABANDON (safe for production)


`ABANDON` on launch = instance gets terminated if bootstrap fails silently. Use this in production so broken instances never enter service.

---

# Core Concepts

**HeartbeatTimeout** — how long ASG waits for your code to call `complete-lifecycle-action` or `record-lifecycle-action-heartbeat`. Clock starts when the hook fires.

**GlobalTimeout** — AWS-enforced hard ceiling (~3.3 hours). No matter how many heartbeat extensions your code sends, the hook resolves at this limit.

**DefaultResult** — what ASG does when the timeout fires with no signal:
- `CONTINUE` — instance proceeds to InService (safe for labs, dangerous for production)
- `ABANDON` — instance is terminated (correct for production bootstrap failures)

**Signaling CONTINUE manually** (what Lambda does in production):
```bash
aws autoscaling complete-lifecycle-action \
  --auto-scaling-group-name <asg-name> \
  --lifecycle-hook-name <hook-name> \
  --instance-id <instance-id> \
  --lifecycle-action-result CONTINUE
```

**Notification targets** — how your code gets called:
- EventBridge → Lambda (most common, exam default answer)
- SNS → subscriber
- SQS → consumer

---

# Real-World Example

Live lab in `devopslab-vpc`, ASG `dop-lab-asg`:

1. Added hook `dop-lab-launch-hook` — `EC2_INSTANCE_LAUNCHING`, HeartbeatTimeout=120, DefaultResult=CONTINUE
2. Scaled ASG to desired=1 — replacement instance `i-0f949c176bba871bb` caught in `Pending:Wait` immediately
3. Attempted manual `complete-lifecycle-action` — hook had already timed out and auto-fired CONTINUE (120s elapsed during polling)
4. Second launch attempt: instance again caught in `Pending:Wait`, confirmed in describe output, then auto-transitioned to `InService` after timeout

Key observation: `complete-lifecycle-action` returns `No active Lifecycle Action found` when the timeout has already fired — the hook resolved itself via DefaultResult. This is expected behavior, not an error in the bootstrap path.

---

# Engineering Analogy

Your `systemd.sh` Packer script runs `systemctl enable` but not `systemctl start` — services are staged on the AMI, not running. They start on first boot at runtime. A lifecycle hook is the same pattern at the ASG layer: the instance exists and is staged, but held in `Pending:Wait` until external logic confirms it is ready to serve traffic.

Your `platform-rehydrate.sh` is exactly what a lifecycle hook would invoke in an ASG-managed fleet — pull config, start services, verify health — then signal CONTINUE.

---

# Best Practices

- Use `DefaultResult: ABANDON` in production — silent bootstrap failures should kill the instance, not let it enter service broken
- Keep `HeartbeatTimeout` realistic — long enough for your slowest bootstrap path, short enough to fail fast
- Use EventBridge → Lambda as the notification target — decoupled, serverless, easiest to test independently
- Test the hook signal path separately from the bootstrap logic — confirm `complete-lifecycle-action` works before wiring in the full Lambda

---

# Common Mistakes

- Setting `DefaultResult: CONTINUE` in production — a broken instance silently enters the fleet and serves errors
- HeartbeatTimeout too short — Lambda cold start + bootstrap time exceeds the window, hook fires ABANDON on healthy instances
- Forgetting that `complete-lifecycle-action` fails silently if the hook already resolved — always check the LifecycleState before signaling

---

# Pro Tip

> If you see `No active Lifecycle Action found` when calling `complete-lifecycle-action`, the HeartbeatTimeout already fired and DefaultResult kicked in. This is not an error — it means your signal window closed. Increase HeartbeatTimeout or speed up your bootstrap logic.

---

# Key Takeaways

- Lifecycle hooks intercept `Pending` and `Terminating` transitions — instances wait until signaled or timed out
- `DefaultResult: ABANDON` is correct for production launch hooks — broken bootstraps should not enter service
- EventBridge → Lambda is the standard notification pattern for exam scenarios
- HeartbeatTimeout and GlobalTimeout are independent — know both values and what triggers each

---

# Related Articles

- DevOpsPro-AWS-Auto-Scaling-Groups-The-Self-Healing-Control-Loop.md
- DevOpsPro-ALB-Target-Groups-and-ASG-Integration.md

---

# References

- AWS Documentation: Amazon EC2 Auto Scaling Lifecycle Hooks
- Live lab performed in devopslab-vpc, account 046685909731, 2026-08-08
