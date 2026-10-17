---
title: "AWS Free Security and Cost Baseline — Plan and Runbook"
date: 2026-10-16
description: "Plan for adding only zero-cost AWS security and cost guardrails to Platform Foundation, with apply and verification steps for each, plus a bill-pruning checklist."
tags:
  - aws
  - cost
  - security
  - cloudtrail
  - budgets
  - imdsv2
  - terraform
categories:
  - Infrastructure
summary: "Adds Access Analyzer, account-level S3 Block Public Access, EBS default encryption, IMDSv2, a free CloudTrail trail, a no-action Budget, and an EC2 status alarm. Nothing here should raise the bill. CloudFront for onwuachi.com is deferred."
---

# AWS Free Security and Cost Baseline — Plan and Runbook

**Status: planned. Nothing below has been applied yet.** Tick each checkbox only after its verification step passes.

---

# Problem

A Tutorials Dojo DOP-C02 lesson on AWS Shield raised two questions: should Shield be "included" on the platform, and which other free AWS services are worth adopting? Constraint: **the bill must not go up.** The September 2026 statement was $12.31 (down from about $15.10 for the July–August window).

Findings:

- Shield Standard is automatic and free on every account. There is nothing to enable. It covers L3/L4 only and does nothing for HTTP floods hitting HAProxy.
- Shield Advanced is about $3,000/month with a 1-year commitment. Rejected.
- CloudFront in front of onwuachi.com would improve DDoS posture within its free tier, but requires security-group prefix-list locking and rework of the `/private /family /secure` basic-auth paths. **Deferred to Phase 5.** onwua.com is already served via CloudFront.

---

# Approach

Only add services whose cost is zero at this scale. Reference: `KB-REF-003` (AWS Free vs Paid Services).

Explicitly **not** adding: GuardDuty, Security Hub, Inspector, Config, WAF, Shield Advanced, Route 53 health checks, CloudTrail data events or Insights, CloudWatch Logs delivery for CloudTrail.

Pricing checked 2026-10-16: Budgets alerts without actions are free (only action-enabled budgets beyond the first 2, and report deliveries, cost money); CloudTrail's first copy of management events per region is free, with storage billed by S3.

---

# Changes

## 1. IAM Access Analyzer (external access only)

```bash
aws accessanalyzer create-analyzer \
  --analyzer-name platform-external-access \
  --type ACCOUNT \
  --region us-east-1
```

Do **not** create an unused-access analyzer; that is a paid feature.

Verify:

```bash
aws accessanalyzer list-analyzers --region us-east-1 \
  --query 'analyzers[].{name:name,type:type,status:status}'
aws accessanalyzer list-findings-v2 --region us-east-1 \
  --analyzer-arn <ANALYZER_ARN> --query 'findings[].{resource:resource,status:status}'
```

- [ ] Applied
- [ ] Findings reviewed

## 2. S3 Block Public Access (account level)

**Check first.** If the onwua.com CloudFront distribution reads from an S3 *website endpoint* or a bucket with a public-read policy, this setting will break the site. An S3 origin using Origin Access Control is unaffected.

```bash
# Find the distribution and inspect how it reaches S3
aws cloudfront list-distributions \
  --query 'DistributionList.Items[].{Id:Id,Aliases:Aliases.Items,Origin:Origins.Items[0].DomainName}'
aws cloudfront get-distribution-config --id <DISTRIBUTION_ID> \
  --query 'DistributionConfig.Origins.Items[].{Domain:DomainName,OAC:OriginAccessControlId,S3:S3OriginConfig,Custom:CustomOriginConfig}'
```

Proceed only if the origin uses OAC (an `OriginAccessControlId` is present and the domain is `*.s3.<region>.amazonaws.com`).

```bash
aws s3control put-public-access-block \
  --account-id <ACCOUNT_ID> \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Verify, then confirm onwua.com still loads:

```bash
aws s3control get-public-access-block --account-id <ACCOUNT_ID>
curl -sI https://onwua.com/ | head -n 1
```

- [ ] Origin confirmed OAC-based
- [ ] Applied
- [ ] onwua.com returns 200

## 3. EBS encryption by default

Uses the AWS-managed `aws/ebs` key (free). Applies to **new** volumes only, per region.

```bash
aws ec2 enable-ebs-encryption-by-default --region us-east-1
aws ec2 get-ebs-encryption-by-default --region us-east-1
```

Existing volumes stay as they are. The `ops-01` root volume becomes encrypted at the next rehydrate (AMI change plus `terraform apply`). Do not use a customer-managed KMS key; that adds $1/month.

- [ ] Applied
- [ ] Next rehydrate: `aws ec2 describe-volumes --filters Name=attachment.instance-id,Values=<INSTANCE_ID> --query 'Volumes[].Encrypted'` returns `true`

## 4. IMDSv2 required

Account default for new launches:

```bash
aws ec2 modify-instance-metadata-defaults --region us-east-1 \
  --http-tokens required --http-put-response-hop-limit 1
```

And in `infra/ops/main.tf`, inside `aws_instance.ops`:

```hcl
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
```

**Hop limit caveat:** with a limit of 1, containers on Docker's bridge network cannot reach the metadata service. Grafana and Prometheus run with `--network host` and are unaffected. If any bridge-networked container needs instance credentials, raise the limit to 2 for that reason only.

Verify after `terraform apply`:

```bash
aws ec2 describe-instances --instance-ids <INSTANCE_ID> \
  --query 'Reservations[].Instances[].MetadataOptions'
```

- [ ] Account default set
- [ ] Terraform block added and applied
- [ ] `HttpTokens` shows `required`
- [ ] Hugo, HAProxy, Grafana, Prometheus still healthy

## 5. CloudTrail trail (management events only)

First check there is not already a trail; a second trail delivering the same events is billed as an additional copy ($2.00 per 100,000 events).

```bash
aws cloudtrail describe-trails --region us-east-1
```

If none exists, draft Terraform (adjust file location; `infra/shared/` is assumed):

```hcl
data "aws_caller_identity" "current" {}

locals {
  trail_name = "platform-mgmt-events"
  trail_arn  = "arn:aws:cloudtrail:us-east-1:${data.aws_caller_identity.current.account_id}:trail/platform-mgmt-events"
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket = "platform-cloudtrail-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Keeps storage cost near zero: logs expire after 90 days
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  rule {
    id     = "expire-90d"
    status = "Enabled"
    filter {}
    expiration {
      days = 90
    }
  }
}

data "aws_iam_policy_document" "cloudtrail_bucket" {
  statement {
    sid = "AWSCloudTrailAclCheck"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }
  statement {
    sid = "AWSCloudTrailWrite"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket.json
}

resource "aws_cloudtrail" "mgmt" {
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  depends_on                    = [aws_s3_bucket_policy.cloudtrail]
}
```

No event selectors, no CloudWatch Logs integration, no Insights. Those are the paid parts.

Verify:

```bash
aws cloudtrail get-trail-status --name platform-mgmt-events --region us-east-1 \
  --query '{Logging:IsLogging,LastDelivery:LatestDeliveryTime,Error:LatestDeliveryError}'
aws s3 ls s3://platform-cloudtrail-<ACCOUNT_ID>/AWSLogs/ --recursive | head
```

Allow up to about 15 minutes for the first delivery.

- [ ] No pre-existing trail confirmed
- [ ] Applied
- [ ] `IsLogging` true, first log object present

## 6. Budget (alerts only, no actions) and Cost Anomaly Detection

A cost budget with email notifications is free. Do **not** attach budget actions.

```hcl
variable "alert_email" {
  type = string
}

resource "aws_budgets_budget" "monthly" {
  name         = "platform-monthly-cost"
  budget_type  = "COST"
  limit_amount = "20"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
```

The $20 limit is a starting point above recent bills (about $12–15); tighten it once a few months of data confirm the floor.

Cost Anomaly Detection: open the Cost Anomaly Detection page in Billing and Cost Management, check whether a default monitor already exists, and add an email subscription if not. Console setup avoids Cost Explorer API charges.

Verify:

```bash
aws budgets describe-budgets --account-id <ACCOUNT_ID> \
  --query 'Budgets[].{name:BudgetName,limit:BudgetLimit.Amount}'
```

- [ ] Budget applied
- [ ] Anomaly monitor and email subscription confirmed in console

## 7. Off-box heartbeat: SNS + CloudWatch status-check alarm

Prometheus and Grafana cannot alert if `ops-01` itself dies. EC2 basic metrics are free, one alarm is inside the free 10, and email via SNS is free.

Place in `infra/ops/main.tf` next to `aws_instance.ops` so the alarm follows the instance across rehydrates (the instance ID changes on every AMI roll):

```hcl
resource "aws_sns_topic" "platform_alerts" {
  name = "platform-alerts"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.platform_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "ops_status_check" {
  alarm_name          = "ops-01-status-check-failed"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  dimensions          = { InstanceId = aws_instance.ops.id }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.platform_alerts.arn]
}
```

Notes:

- `treat_missing_data = "notBreaching"` stops `platform down` (intentional stop) from paging. The trade-off: this alarm catches hung or impaired instances, not an intentionally or accidentally **stopped** one.
- The email subscription stays "Pending confirmation" until the confirmation link is clicked.
- If `alert_email` is declared in two Terraform roots, declare it once per root.

Verify:

```bash
aws cloudwatch describe-alarms --alarm-names ops-01-status-check-failed \
  --query 'MetricAlarms[].{state:StateValue,dim:Dimensions}'
aws sns list-subscriptions-by-topic --topic-arn <TOPIC_ARN> \
  --query 'Subscriptions[].SubscriptionArn'
```

The subscription ARN must be a real ARN, not `PendingConfirmation`.

- [ ] Applied
- [ ] Email subscription confirmed
- [ ] Alarm state `OK` after rehydrate

## 8. Trusted Advisor (basic)

No setup. Open Trusted Advisor in the console and review the security checks monthly. Treat anything flagged on open security groups or public snapshots as a finding to triage.

- [ ] First review done

---

# Bill-pruning checklist (review before deleting anything)

Goal is a lower bill, not just a flat one. From the July–August breakdown, the larger lines were EC2 compute, EC2-Other, VPC, and Route 53. Each command below only lists; deletion is a separate decision.

```bash
# Secrets Manager: about $0.40/secret/month. SSM SecureString is the free pattern already in use
aws secretsmanager list-secrets --query 'SecretList[].{name:Name,lastUsed:LastAccessedDate}'

# Legacy AMIs and their snapshots (old naming schemes are never auto-pruned by the Packer post-processor)
aws ec2 describe-images --owners self --query 'Images[].{id:ImageId,name:Name,created:CreationDate}'
aws ec2 describe-snapshots --owner-ids self \
  --query 'Snapshots[].{id:SnapshotId,gb:VolumeSize,desc:Description}'

# Unattached EBS volumes
aws ec2 describe-volumes --filters Name=status,Values=available \
  --query 'Volumes[].{id:VolumeId,gb:Size}'

# Unassociated Elastic IPs (public IPv4 is billed hourly, attached or not)
aws ec2 describe-addresses --query 'Addresses[?AssociationId==`null`]'

# Stray Route 53 hosted zones (about $0.50/month each)
aws route53 list-hosted-zones --query 'HostedZones[].{name:Name,id:Id}'
```

Also: `check-bill.sh` calls the Cost Explorer API at $0.01 per request. Run it on demand, not on a schedule, or use the free console view.

- [ ] Secrets reviewed
- [ ] Legacy AMIs/snapshots reviewed
- [ ] Volumes, EIPs, hosted zones reviewed

---

# Result

Pending. After applying, record here:

- Date applied and commit hashes
- Whether the next bill moved (expected: no change, or a few cents of S3 storage for CloudTrail logs)
- Anything that broke (watch onwua.com after step 2 and the container health after step 4)

Deferred:

- CloudFront in front of onwuachi.com (Phase 5): prefix-list-restricted security group, no-cache and `Authorization` forwarding for `/private /family /secure`
- GuardDuty / Config / WAF: out of scope while the goal is zero added spend
