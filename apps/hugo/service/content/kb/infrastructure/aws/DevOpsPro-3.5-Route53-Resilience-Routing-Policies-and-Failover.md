+++
title = "Route 53 Resilience: Routing Policies and Failover"
date = "2026-08-08"
description = "Route 53 routing policies for resilience — failover, weighted, latency, and geolocation — and how health checks drive automatic DNS-level traffic shifting."
tags = ["aws", "route53", "dns", "failover", "resilience", "dop-c02"]
categories = ["aws", "dop-c02"]
summary = "Route 53 routing policy patterns for DOP-C02 — when to use failover vs weighted vs latency routing, and how health checks integrate for automatic regional failover."
draft = false
type = "kb-article"
weight = 0
+++

# Overview

Route 53 routing policies control how DNS responds to queries — returning different endpoints based on health, weight, latency, or geography. For resilience, failover and latency routing are the primary exam patterns. Health checks attached to records enable automatic DNS-level traffic shifting without human intervention.

<!--more-->

# Why It Matters

DNS is the first layer of traffic control in a multi-region architecture. Route 53 routing policies let you shift traffic away from a failed region, distribute load across regions by latency, or run canary deployments at the DNS level — all without touching application code or load balancer config.

# Where It Fits

DOP-C02 Domain 3 — Resilient Cloud Solutions

User DNS query
|
v
Route 53 (evaluates routing policy + health checks)
|
+-- Failover: primary healthy? → primary ALB
| primary unhealthy? → secondary ALB
|
+-- Weighted: 90% → v1 ALB, 10% → v2 ALB
|
+-- Latency: user in EU → eu-west-1 ALB
user in US → us-east-1 ALB


---

# The Big Picture

Routing Policy Use Case Exam Trigger

Simple Single endpoint, no HA Basic DNS only
Weighted Canary deploy, A/B test "shift % of traffic"
Latency Serve from closest region "lowest latency globally"
Failover Active/passive DR "automatic regional failover"
Geolocation Route by country/continent "compliance, data residency"
Geoproximity Route by distance + bias tuning "fine-grained geographic control"
Multivalue Multiple IPs + health checks "simple load distribution with health"


---

# Core Concepts

**Failover routing — the primary DR pattern:**

Primary record
└── ALB in us-east-1
└── Health check attached (required)

Secondary record
└── ALB in us-west-2 (or S3 static site)
└── No health check required
└── Only receives traffic when primary fails


Health check must be on the PRIMARY record. Secondary has no health check — it is the fallback.

**Health check types:**
- `HTTP/HTTPS/TCP` — hits a public endpoint directly
- `Calculated` — aggregates multiple checks with AND/OR logic
- `CloudWatch alarm` — for private resources not reachable from Route 53 infrastructure

**Exam trap:** Route 53 health checks originate from AWS infrastructure — the endpoint must be publicly reachable. Private VPC resources need CloudWatch alarm-based health checks.

**TTL and failover speed:**
- Low TTL (60s) = faster failover, more DNS queries (higher cost)
- High TTL (300s+) = slower failover, fewer queries
- Trade-off: failover speed vs DNS query cost

**Weighted routing for canary at DNS level:**

weight 90 → ALB v1 (stable)
weight 10 → ALB v2 (new version)

Different from CodeDeploy canary (target group level) — this operates at DNS, affects all traffic before it hits any load balancer.

**S3 static site as secondary** — cheapest DR pattern for web apps:

Primary: Route 53 → ALB → dynamic app (us-east-1)
Secondary: Route 53 → S3 static site (us-west-2)

On primary failure, users see a static maintenance/cached page — zero compute cost for the DR endpoint.

---

# Real-World Example

No live lab — Route 53 health checks bill ~$0.50/month per check. Pattern recognition is the exam skill here, not CLI syntax.

Failover architecture for onwuachi.com equivalent:

onwuachi.com
|
+-- PRIMARY: A record → us-east-1 ALB
| Health check: HTTPS GET /health → expect 200
| TTL: 60
|
+-- SECONDARY: A record → S3 static site (us-west-2)
Failover: SECONDARY
TTL: 60


If the us-east-1 ALB health check fails two consecutive times → Route 53 stops returning the primary record → all new DNS queries resolve to the S3 static site.

---

# Engineering Analogy

Route 53 failover routing is the DNS-layer equivalent of HAProxy's `option httpchk` on a backend server — if the health check fails, the backend is taken out of rotation. The difference is Route 53 operates at the DNS level (affects all traffic globally) while HAProxy operates at the proxy level (affects traffic hitting that specific proxy instance).

---

# Best Practices

- Always attach health checks to PRIMARY failover records — without one, Route 53 always returns the primary regardless of health
- Use CloudWatch alarm health checks for private resources — direct HTTP checks can't reach VPC-internal endpoints
- Keep TTL low (60s) for failover records — high TTL means clients cache the failed endpoint longer
- Use S3 static site as a cheap, always-available secondary for DR
- Test failover by manually disabling the health check before relying on it in production

---

# Common Mistakes

- Attaching health check to secondary record instead of primary — failover never triggers
- Using high TTL on failover records — slow failover defeats the purpose
- Assuming Route 53 health checks can reach private VPC resources — they cannot without CloudWatch alarm integration
- Confusing Route 53 weighted routing (DNS level) with CodeDeploy canary (target group level) — both shift traffic percentages but at different layers

---

# Pro Tip

> Route 53 failover does not happen instantly — it requires the health check to fail consecutively (default: 3 times) plus TTL expiry on cached records. Total failover time = (failure threshold × check interval) + TTL. Design accordingly.

---

# Key Takeaways

- Failover routing requires a health check on the PRIMARY record only
- Route 53 health checks need public endpoints — use CloudWatch alarms for private resources
- Low TTL = faster failover at higher DNS query cost — balance based on RTO requirements
- Weighted routing at DNS level affects all traffic before it hits any load balancer — coarser than CodeDeploy canary
- S3 static site as secondary is the cheapest always-available DR endpoint

---

# Related Articles

- DevOpsPro-Multi-Region-Architecture-Patterns.md
- DevOpsPro-ALB-Target-Groups-and-ASG-Integration.md

---

# References

- AWS Documentation: Amazon Route 53 Routing Policies
- AWS Documentation: Route 53 Health Checks
