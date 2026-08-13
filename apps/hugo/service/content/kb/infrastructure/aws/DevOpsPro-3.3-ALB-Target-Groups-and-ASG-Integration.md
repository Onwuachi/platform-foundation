+++
title = "ALB, Target Groups, and ASG Integration"
date = "2026-08-08"
description = "How Application Load Balancer listeners, target groups, and Auto Scaling Groups wire together for traffic distribution and ELB-driven self-healing."
tags = ["aws", "alb", "target-groups", "asg", "load-balancing", "dop-c02", "ec2"]
categories = ["aws", "dop-c02"]
summary = "Built a full ALB + ASG stack from CLI — listener, target group, health checks, ELB-driven replacement — mapped against the HAProxy mental model."
draft = false
type = "kb-article"
weight = 0
+++

# Overview

An Application Load Balancer (ALB) operates at Layer 7 and distributes HTTP/HTTPS traffic across a Target Group of registered instances. When integrated with an ASG, instances register and deregister automatically — and ALB health checks drive ASG instance replacement when an application (not just the VM) is unhealthy.

<!--more-->

# Why It Matters

EC2 health checks only detect VM-level failure. An instance can be running and passing EC2 checks while the application inside is broken. ELB health checks detect application-level failure — and when wired to an ASG, trigger automatic replacement. This is the difference between infrastructure self-healing and application self-healing.

# Where It Fits

DOP-C02 Domain 3 — Resilient Cloud Solutions

Internet
|
v
ALB (Layer 7)
|
v
Listener :80/:443
|
v
Listener Rules (path/host routing)
|
v
Target Group
|
+-- Health Check (:80, GET /, expect 200)
|
+-- Instance 1 (ASG-managed)
+-- Instance 2 (ASG-managed)


---

# The Big Picture

HAProxy AWS Equivalent

frontend (bind *:80) → ALB Listener
acl / use_backend → Listener Rules
backend → Target Group
server (health check) → Target Group Health Check
balance roundrobin → ALB default routing


ALB is managed HAProxy — same mental model, AWS operates the infrastructure.

---

# Core Concepts

**Load Balancer Types — pick the right one:**
- `ALB` — Layer 7, HTTP/HTTPS, path and host-based routing — default exam answer for web traffic
- `NLB` — Layer 4, TCP/UDP, static IPs, TLS passthrough, ultra-low latency
- `GLB` — Layer 3, routes traffic through third-party security appliances (firewalls, IDS)

**ALB requires two subnets in different AZs** — single-AZ ALB is not supported. Always pass at least two public subnets on creation.

**Target Group** — the backend pool. Health check config lives here, not on the ALB. Targets can be EC2 instances, IP addresses, Lambda functions, or another ALB.

**Health check fields that matter:**
- `HealthCheckPath` — what URL the ALB hits (equivalent to HAProxy `option httpchk`)
- `HealthyThresholdCount` — consecutive successes before marking healthy (lab: 2)
- `UnhealthyThresholdCount` — consecutive failures before marking unhealthy (lab: 2)
- `Matcher.HttpCode` — expected response code (default: 200)

**ELB health check type on ASG** — switches ASG from EC2 checks to ALB checks. When the Target Group marks an instance unhealthy, ASG terminates and replaces it.

**Health check grace period** — how long ASG waits after launch before starting ELB health checks. Set this longer than your bootstrap time or ASG will terminate instances before they finish starting.

---

# Real-World Example

Full stack built via CLI in `devopslab-vpc`:

**Resources created:**
- ALB `dop-lab-alb` — internet-facing, subnets 1a + 1b, security group `dop-lab-sg`
- Target Group `dop-lab-tg` — HTTP:80, health check `GET /` expect 200, thresholds 2/2
- Listener — HTTP:80 → forward to `dop-lab-tg`
- ASG updated — health-check-type ELB, grace period 60s, desired=2

**Verified:**
- Single instance registered healthy in target group
- Scaled to desired=2 — second instance auto-registered
- `watch -n2 curl` confirmed ALB round-robining between `ip-10-50-1-86` and `ip-10-50-1-203`

**Teardown order (dependency-first):**
1. Delete Listener
2. Delete ALB
3. Delete Target Group
4. Scale ASG to 0/0/0

---

# ALB + ASG Build Runbook

```bash
# 1. Create ALB (requires 2 subnets in different AZs)
aws elbv2 create-load-balancer \
  --name <alb-name> \
  --subnets <subnet-1a> <subnet-1b> \
  --security-groups <sg-id> \
  --scheme internet-facing \
  --type application

# 2. Create Target Group
aws elbv2 create-target-group \
  --name <tg-name> \
  --protocol HTTP --port 80 \
  --vpc-id <vpc-id> \
  --health-check-path / \
  --health-check-interval-seconds 30 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 2

# 3. Create Listener
aws elbv2 create-listener \
  --load-balancer-arn <alb-arn> \
  --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn=<tg-arn>

# 4. Attach Target Group to ASG
aws autoscaling attach-load-balancer-target-groups \
  --auto-scaling-group-name <asg-name> \
  --target-group-arns <tg-arn>

# 5. Switch ASG to ELB health checks
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name <asg-name> \
  --health-check-type ELB \
  --health-check-grace-period 60

# 6. Verify target health
aws elbv2 describe-target-health \
  --target-group-arn <tg-arn> \
  --output table

# Teardown (billing stops when ALB is deleted)
aws elbv2 delete-listener --listener-arn <listener-arn>
aws elbv2 delete-load-balancer --load-balancer-arn <alb-arn>
aws elbv2 delete-target-group --target-group-arn <tg-arn>
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name <asg-name> \
  --min-size 0 --max-size 0 --desired-capacity 0
```

---

# Engineering Analogy

Your HAProxy config has a `frontend` binding a port, `acl` rules routing to named `backend` blocks, each with `server` lines and `option httpchk`. ALB is that exact architecture — Listener = frontend, Rules = acl/use_backend, Target Group = backend, health check = httpchk. The difference is AWS manages the proxy infrastructure and integrates it with ASG so backends register and deregister automatically.

---

# Best Practices

- Always set `--health-check-grace-period` longer than your slowest bootstrap — premature ELB checks terminate healthy instances mid-startup
- Use `describe-target-health` to confirm registration before testing traffic
- Teardown listener before ALB — dependency order prevents API errors
- Use path-based routing rules for microservices (`/api/*` → TG-A, `/web/*` → TG-B) rather than separate ALBs per service

---

# Common Mistakes

- Creating ALB with only one subnet — fails immediately, ALB requires multi-AZ
- Forgetting to switch ASG health check type to ELB — ASG keeps using EC2 checks only, app failures don't trigger replacement
- Grace period too short — ASG terminates instances that are still bootstrapping
- Leaving ALB running after a lab — unlike EC2, ALB bills by the hour even with zero targets

---

# Pro Tip

> `describe-target-health` is your first debugging tool when traffic isn't reaching instances. Check State (`initial`, `healthy`, `unhealthy`) and the Description field — it tells you exactly why a target failed health checks (connection refused, timeout, wrong HTTP code).

---

# Key Takeaways

- ALB = managed HAProxy — same mental model, AWS operates the infrastructure
- Target Groups hold health check config — not the ALB itself
- ELB health check type on ASG is what enables application-level self-healing, not just VM-level
- ALB requires two subnets in different AZs — single-AZ is not supported
- Teardown order matters: Listener → ALB → Target Group → ASG scale-down

---

# Related Articles

- DevOpsPro-AWS-Auto-Scaling-Groups-The-Self-Healing-Control-Loop.md
- DevOpsPro-ASG-Lifecycle-Hooks-Pending-Wait-and-Bootstrap-Control.md

---

# References

- AWS Documentation: Application Load Balancers
- AWS Documentation: Target Groups for your Application Load Balancers
- Live lab performed in devopslab-vpc, account 046685909731, 2026-08-08
- 
