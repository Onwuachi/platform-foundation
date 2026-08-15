+++
title = "CloudTrail: API Audit and Event History"
date = "2026-08-15"
description = "CloudTrail records every AWS API call for audit, compliance, and incident investigation — covering event types, trail config, LookupEvents, and the alerting pipeline."
tags = ["aws", "cloudtrail", "audit", "security", "monitoring", "dop-c02"]
categories = ["aws", "dop-c02"]
summary = "CloudTrail event types, trail configuration, LookupEvents for free 90-day history, and the CloudTrail → CloudWatch Logs → Metric Filter → Alarm alerting pattern."
draft = false
type = "kb-article"
weight = 0
+++

# Overview

CloudTrail records every API call made in your AWS account — who called what, when, from where, and with what result. It is the audit log for the AWS control plane. Every CLI command, console action, and SDK call creates a CloudTrail event.

<!--more-->

# Why It Matters

Without CloudTrail, there's no answer to "who terminated that instance?" or "who changed that security group?" CloudTrail is the foundation for security auditing, compliance, incident investigation, and automated response to unauthorized API activity.

# Where It Fits

DOP-C02 Domain 4 — Monitoring and Logging

AWS API call (CLI / Console / SDK)
|
v
CloudTrail (records event)
|
+-- S3 bucket (raw gzipped JSON, long-term storage)
|
+-- CloudWatch Logs (real-time alerting pipeline)
|
v
Metric Filter → Alarm → SNS


---

# The Big Picture

CloudTrail Event fields:

Who: userIdentity (IAM user, role, service)
What: eventName (TerminateInstances, DeleteBucket, PutBucketPolicy)
When: eventTime
Where: sourceIPAddress
Which: requestParameters (instance IDs, bucket names, etc.)
Result: errorCode (present only on failures)

---

# Core Concepts

**Three event types:**

Management Events (default, free first copy per region):
- Control plane operations: CreateBucket, TerminateInstances, PutPolicy, AttachRolePolicy
- Everything you do in the console or CLI

Data Events (extra cost ~$0.10/100k):
- S3 object-level: GetObject, PutObject, DeleteObject
- Lambda invocations
- DynamoDB item-level operations
- Not enabled by default — must opt in

Insights Events (extra cost):
- Detects unusual API activity patterns (anomaly detection)
- Exam trigger: "detect anomalous API behavior automatically" → CloudTrail Insights

**Trail configuration — exam-relevant settings:**

Multi-region trail — one trail covers all regions (recommended, default for new trails)
Log file validation — SHA-256 hash chain proves logs weren't tampered with
S3 bucket — where raw trail logs land (gzipped JSON, ~15 min delay)
CloudWatch Logs — ship trail events for real-time alerting (separate config)


**LookupEvents — free, no trail needed:**
```bash
aws cloudtrail lookup-events \
  --max-results 5 \
  --query "Events[*].{Time:EventTime,User:Username,Event:EventName}" \
  --output table
```
Last 90 days of management events, queryable for free without a trail configured. Use for quick incident investigation.

**Alerting pipeline — the exam standard pattern:**

CloudTrail → CloudWatch Logs integration
|
v
Metric Filter (pattern: "DeleteBucket" or "{ $.errorCode = "AccessDenied" }")
|
v
CloudWatch Alarm (threshold > 0)
|
v
SNS → email / Lambda


Use case: alert when someone deletes an S3 bucket, when root account is used, or when there are repeated authorization failures.

**Global service events:**
IAM, STS, Route 53 events only log in us-east-1. A multi-region trail captures them because it includes us-east-1. A single-region trail in another region misses them.

---

# Real-World Example

Live check in devopslab, account 046685909731:

`describe-trails` returned empty — no custom trail configured. Account relies on default 90-day event history only.

`lookup-events` returned live activity from the ops instance `i-065af3b16c9f91e27`:
- `UpdateInstanceInformation` — SSM Agent heartbeat
- `BatchGetImage` — ECR image pull
- `ListInstanceAssociations` — SSM association sync

This confirms CloudTrail event history is always on even without a trail — the ops instance's normal activity is fully auditable for free.

**What a trail adds beyond free event history:**
- Long-term retention beyond 90 days (S3)
- Real-time alerting via CloudWatch Logs integration
- Data events (S3 object-level, Lambda invocations)
- Multi-account aggregation via CloudTrail Lake or S3

**Platform-foundation gap:** No trail configured — all API activity only retained 90 days. Adding a multi-region trail shipping to CloudWatch Logs would enable alerting on unauthorized API calls.

---

# Engineering Analogy

CloudTrail is the AWS equivalent of Linux `auditd` — every syscall logged with who, what, when, and result. `lookup-events` is `ausearch`. The CloudTrail → CloudWatch Logs → Metric Filter pipeline is the equivalent of `auditd` → `syslog` → `grep` → alerting.

---

# Best Practices

- Enable a multi-region trail — single-region trails miss global service events (IAM, STS, Route 53)
- Enable log file validation — proves chain of custody for compliance audits
- Ship to CloudWatch Logs for real-time alerting — S3 alone has ~15 minute delay
- Enable Data Events for S3 buckets containing sensitive data — default management events miss object-level access
- Use `lookup-events` for quick investigation before standing up full trail infrastructure

---

# Common Mistakes

- Assuming CloudTrail is real-time — S3 delivery has ~15 minute delay; CloudWatch Logs integration is near-real-time
- Single-region trail missing IAM/STS/Route53 events — those only log in us-east-1
- Not enabling log file validation — can't prove logs weren't tampered with during an audit
- Data events disabled — S3 object access (GetObject, DeleteObject) not captured by default

---

# Pro Tip

> `aws cloudtrail lookup-events` is free for the last 90 days and requires no trail — use it first during incident investigation before assuming you need a trail. Filter by event name, resource, or time window: `--lookup-attributes AttributeKey=EventName,AttributeValue=TerminateInstances`

---

# Key Takeaways

- CloudTrail records who, what, when, where, which resource, and result for every API call
- Event history (90 days, free) is always on; a Trail adds long-term storage, alerting, and data events
- Multi-region trail is required to capture IAM/STS/Route53 global service events
- CloudTrail → CloudWatch Logs → Metric Filter → Alarm is the standard audit alerting pattern
- `lookup-events` is free, instant, and requires no trail configuration

---

# Related Articles

- DevOpsPro-4.2-CloudWatch-Logs-and-Metric-Filters.md
- DevOpsPro-4.4-EventBridge-Event-Driven-Automation.md
- DevOpsPro-4.7-AWS-Config-Compliance-and-Auto-Remediation.md

---

# References

- AWS Documentation: AWS CloudTrail User Guide
- Live check performed in devopslab-vpc, account 046685909731, 2026-08-15
