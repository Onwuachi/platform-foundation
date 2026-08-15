+++
title = "AWS Config: Compliance and Auto-Remediation"
date = "2026-08-15"
description = "AWS Config continuously records resource configuration state and evaluates compliance rules — with auto-remediation via SSM Automation for non-compliant resources."
tags = ["aws", "config", "compliance", "remediation", "ssm", "dop-c02"]
categories = ["aws", "dop-c02"]
summary = "AWS Config rule types, configuration timeline, auto-remediation pattern with SSM Automation, and the exam decision framework for compliance vs prevention vs audit."
draft = false
type = "kb-article"
weight = 0
+++

# Overview

AWS Config continuously records the configuration state of your AWS resources and evaluates them against rules you define. It answers two questions: "what did this resource look like at a point in time?" and "is this resource compliant with our standards right now?"

<!--more-->

# Why It Matters

Infrastructure drift is inevitable — someone opens a security group port manually, a bucket loses its encryption setting, an IAM role gains excessive permissions. AWS Config detects these changes continuously and can trigger automated remediation, closing the loop without human intervention.

# Where It Fits

DOP-C02 Domain 4 — Monitoring and Logging

Resource created or changed
|
v
AWS Config recorder (captures configuration snapshot)
|
v
Config Rule evaluation (COMPLIANT or NON_COMPLIANT)
|
v
EventBridge event (NON_COMPLIANT)
|
v
SSM Automation (auto-remediate) or SNS (notify)


---

# The Big Picture

Two core functions:

Configuration Timeline
EC2 instance created → SG changed → instance terminated
Full history of every configuration change, queryable by time
Compliance Rules
"All S3 buckets must have encryption"
Config evaluates continuously → COMPLIANT or NON_COMPLIANT

---

# Core Concepts

**Rule types:**

AWS Managed Rules (pre-built, 100+ available):

s3-bucket-server-side-encryption-enabled
ec2-instance-no-public-ip
iam-root-access-key-check
restricted-ssh — no 0.0.0.0/0 on port 22
mfa-enabled-for-iam-console-access
cloudtrail-enabled


Custom Rules — Lambda function evaluates compliance:
- Use when AWS doesn't have a managed rule for your business logic
- Lambda receives resource config and returns COMPLIANT/NON_COMPLIANT

Conformance Packs — bundled rule sets for frameworks:
- CIS AWS Foundations Benchmark
- PCI-DSS
- HIPAA
- Deploy as a single unit across an account or organization

**Evaluation triggers:**

Configuration change — evaluates when resource config changes
Periodic — evaluates on a schedule (1hr, 3hr, 6hr, 12hr, 24hr)

Some rules only support one trigger type — know which for the exam.

**Auto-remediation pattern:**

Config Rule: restricted-ssh
|
v
Security group with 0.0.0.0/0 on port 22 → NON_COMPLIANT
|
v
Config triggers SSM Automation: AWS-DisablePublicAccessForSecurityGroup
|
v
SSM removes the offending rule automatically
|
v
Re-evaluation → COMPLIANT


**Aggregator — multi-account/multi-region:**
- Collects Config data from multiple accounts and regions into one view
- Requires IAM role in each source account
- Used in AWS Organizations for centralized compliance dashboard

**Cost:**
- $0.003 per configuration item recorded
- $0.001 per Config rule evaluation
- Can add up in large accounts with many resources changing frequently

---

# Real-World Example

No live lab — Config recorder has per-resource cost and requires careful scoping.

**Exam decision tree — compliance scenarios:**

"Block action before it happens"
→ SCP (Service Control Policy) or IAM Permission Boundary

"Detect non-compliance and alert"
→ AWS Config Rule + SNS notification

"Detect and fix non-compliance automatically"
→ AWS Config Rule + SSM Automation remediation

"Audit who made a change"
→ CloudTrail (who) + Config timeline (what changed)

"See what a resource looked like before the change"
→ AWS Config configuration timeline

"Apply compliance rules across entire organization"
→ Config Conformance Pack via AWS Organizations


**Config vs CloudTrail — the common exam distinction:**

CloudTrail → WHO made the API call (identity, source IP, timestamp)
AWS Config → WHAT the resource looks like (configuration state, compliance)


Both together give you the full picture: Config shows the bucket lost encryption at 2pm; CloudTrail shows who made the PutBucketEncryption call at 2pm.

---

# Engineering Analogy

AWS Config is the equivalent of continuous `terraform plan` output — it shows you the diff between your desired state (Config rules) and actual state (recorded configuration) at all times. CloudFormation Drift Detection (which you ran in Domain 2) is the CloudFormation-scoped version of what Config does account-wide for all resource types continuously.

---

# Best Practices

- Scope the Config recorder to relevant resource types — recording all resources in a large account generates significant cost
- Start with AWS Managed Rules for common compliance requirements before writing custom Lambda rules
- Use Conformance Packs for regulatory frameworks — pre-tested rule bundles are faster than building from scratch
- Pair Config rules with SSM Automation for auto-remediation — closes the loop without human intervention
- Use Config Aggregator for multi-account organizations — single compliance dashboard across all accounts

---

# Common Mistakes

- Confusing Config (what changed) with CloudTrail (who changed it) — both are needed for full audit
- Assuming Config is preventative — it detects and reports, it does not block; use SCP or IAM for prevention
- Recording all resource types without scoping — cost grows with every resource change in a large account
- Periodic-only rules for security findings that need immediate detection — use configuration-change trigger instead

---

# Pro Tip

> AWS Config's configuration timeline is invaluable during incident investigation — navigate to any resource in the Config console, click Timeline, and see the exact configuration at any point in the past. Pair with CloudTrail's `lookup-events` filtered by the same time window to get both what changed and who changed it.

---

# Key Takeaways

- Config records configuration state (what); CloudTrail records API calls (who) — they complement each other
- Config is detective, not preventative — use SCP/IAM to block, Config to detect
- Auto-remediation: Config Rule → SSM Automation → resource fixed automatically
- Conformance Packs bundle rules for CIS, PCI-DSS, HIPAA — deploy as a single unit
- Config Aggregator enables multi-account/multi-region compliance visibility

---

# Related Articles

- DevOpsPro-4.4-EventBridge-Event-Driven-Automation.md
- DevOpsPro-4.5-CloudTrail-API-Audit-and-Event-History.md

---

# References

- AWS Documentation: AWS Config Developer Guide
- AWS Documentation: AWS Config Managed Rules
- AWS Documentation: Conformance Packs
