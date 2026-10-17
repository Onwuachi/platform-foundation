---
title: "KB-REF-003 — AWS Free vs Paid Services (Security, Monitoring, Cost)"
date: 2026-10-16
description: "Reference for which AWS security, monitoring, and cost-control services are free, which only look free, and what each costs once you cross the line."
tags:
  - aws
  - cost
  - security
  - shield
  - cloudtrail
  - budgets
  - free-tier
categories:
  - Infrastructure
summary: "Shield Standard, Budgets alerts, Access Analyzer, and a first CloudTrail trail cost nothing; GuardDuty, Config, WAF, and Shield Advanced do not. Know the line before enabling anything."
---

# AWS Free vs Paid Services (Security, Monitoring, Cost)

Quick reference for a cost-conscious single-account platform: what is genuinely free, what only looks free, and what to skip. Pricing last checked against AWS pricing pages on **2026-10-16** for Budgets and CloudTrail; other rows reflect AWS documentation as understood at that date. Confirm on the service's pricing page before enabling anything.

---

# Always on (nothing to enable)

| Service | What you get | Limit to know |
|---|---|---|
| AWS Shield Standard | Automatic L3/L4 DDoS protection on every account | Cannot be enabled, disabled, or tuned. Does nothing for HTTP floods |
| CloudTrail Event History | 90 days of management events, searchable in console | Per region; not queryable beyond 90 days |
| Trusted Advisor (basic) | Core security checks (open security groups, public snapshots, root MFA, etc.) | Full check set requires a paid support plan |
| SSM Session Manager | Shell access with no inbound ports | Free; session logging to S3/CloudWatch is billed as storage/ingest |
| SSM Parameter Store (standard tier) | Config and SecureString secrets | Advanced-tier parameters are billed |
| IAM / IAM Identity Center | Users, roles, SSO | Free |

---

# Free once you turn them on

| Service | Free part | Where it turns paid |
|---|---|---|
| AWS Budgets | Cost/usage budgets with email alerts: free | Action-enabled budgets beyond the first 2 cost $0.10/day each; Budgets Reports cost $0.01 per delivery |
| Cost Anomaly Detection | Free | Nothing meaningful for one account |
| IAM Access Analyzer (external access) | Free findings for public/cross-account access | The "unused access" analyzer is a separate, paid feature. Do not enable it |
| S3 Block Public Access (account level) | Free | Nothing. Check that no CloudFront origin relies on a public bucket first |
| EBS encryption by default | Free with the AWS-managed `aws/ebs` key | Customer-managed KMS keys cost $1/month each |
| IMDSv2 enforcement | Free | Nothing |
| CloudTrail trail | First copy of management events per region delivered to S3: free | You pay S3 storage; additional trails, data events, Insights, and CloudWatch Logs delivery are all billed. Data events are charged from the first event |
| CloudWatch free tier | 10 alarms, 10 custom metrics, basic EC2 metrics (5-min), limited log ingest | Detailed monitoring, extra alarms, and log storage beyond the allowance |
| SNS | 1M requests/month | SMS and some delivery protocols are billed; email is fine |

---

# Looks free, is not

| Service | Reality |
|---|---|
| GuardDuty, Security Hub, Inspector | Time-limited trials, then billed by usage |
| AWS Config | Billed per configuration item recorded and per rule evaluation; adds up fast |
| AWS WAF | Per web ACL, per rule, and per request |
| Shield Advanced | About $3,000/month with a 1-year commitment. Not appropriate below enterprise scale |
| Secrets Manager | About $0.40 per secret per month. SSM SecureString is the free alternative |
| Cost Explorer API | $0.01 per request. The console UI is free; scripts that poll the API are not |
| Route 53 | Hosted zones about $0.50/month each; health checks billed separately |
| Public IPv4 addresses | Billed hourly per address, attached or not |
| VPC Flow Logs, NAT Gateway | Ingest and per-hour/per-GB charges |

---

# Shield Standard vs Advanced (exam and real-world)

- **Standard:** automatic, free, L3/L4 only. Best protection is on CloudFront and Route 53, which absorb attacks at the edge.
- **Advanced:** paid, adds L7 detection, DDoS Response Team access, cost protection, and WAF integration for covered resources (EC2/EIP, ELB, CloudFront, Global Accelerator, Route 53).
- For HTTP floods on a single origin, the practical free-ish lever is putting CloudFront in front (always-free tier covers 1 TB transfer and 10M requests per month). That requires locking the origin security group to CloudFront's managed prefix list and deciding how authenticated paths behave (no caching, forward the `Authorization` header).

---

# Verification

```bash
# Is a CloudTrail trail already delivering management events?
aws cloudtrail describe-trails --region us-east-1

# Which budgets exist, and are any action-enabled?
aws budgets describe-budgets --account-id <ACCOUNT_ID>

# What is actually driving the bill? (console Cost Explorer is free; API is $0.01/request)
./scripts/check-bill.sh 31
```

---

# Related

- `docs/aws-free-baseline-2026-10-16.md` — session writeup applying this list to Platform Foundation
- `KB-WEB-001` — CloudFront/S3/Hugo 403 fix (onwua.com)
