##############################
# AWS free baseline (root module)
# - CloudTrail: ONE multi-region trail, management events only
#   (first copy is free; data events, Insights, and CloudWatch Logs
#   delivery are the paid parts and are deliberately NOT enabled)
# - Budgets: alert-only cost budget (no budget actions, so no charge)
#
# Prerequisite (one time, outside Terraform):
#   aws ssm put-parameter --name /platform/alerts/email --type String \
#     --value '<your email>' --region us-east-1
##############################
data "aws_caller_identity" "baseline" {}

data "aws_ssm_parameter" "baseline_alert_email" {
  name = "/platform/alerts/email"
}

locals {
  baseline_trail_name = "platform-mgmt-events"
  baseline_trail_arn  = "arn:aws:cloudtrail:${var.aws_region}:${data.aws_caller_identity.baseline.account_id}:trail/${local.baseline_trail_name}"
}

##############################
# CloudTrail log bucket (private, 90-day expiry keeps storage near zero)
##############################
resource "aws_s3_bucket" "baseline_cloudtrail" {
  bucket = "platform-cloudtrail-${data.aws_caller_identity.baseline.account_id}"
}

resource "aws_s3_bucket_public_access_block" "baseline_cloudtrail" {
  bucket                  = aws_s3_bucket.baseline_cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "baseline_cloudtrail" {
  bucket = aws_s3_bucket.baseline_cloudtrail.id

  rule {
    id     = "expire-90d"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }
  }
}

data "aws_iam_policy_document" "baseline_cloudtrail_bucket" {
  statement {
    sid = "AWSCloudTrailAclCheck"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.baseline_cloudtrail.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.baseline_trail_arn]
    }
  }

  statement {
    sid = "AWSCloudTrailWrite"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.baseline_cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.baseline.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.baseline_trail_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "baseline_cloudtrail" {
  bucket     = aws_s3_bucket.baseline_cloudtrail.id
  policy     = data.aws_iam_policy_document.baseline_cloudtrail_bucket.json
  depends_on = [aws_s3_bucket_public_access_block.baseline_cloudtrail]
}

resource "aws_cloudtrail" "baseline_mgmt" {
  name                          = local.baseline_trail_name
  s3_bucket_name                = aws_s3_bucket.baseline_cloudtrail.id
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket_policy.baseline_cloudtrail]
}

##############################
# Cost budget: alerts only. Do NOT add budget actions (paid beyond the first 2).
# $20 sits above recent bills (about $12-15); tighten once a few months confirm the floor.
##############################
resource "aws_budgets_budget" "baseline_monthly" {
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
    subscriber_email_addresses = [data.aws_ssm_parameter.baseline_alert_email.value]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [data.aws_ssm_parameter.baseline_alert_email.value]
  }
}
