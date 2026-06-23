###############################################
# onwua.com — Static Portfolio Infrastructure
# S3 origin + CloudFront + Route53 + ACM TLS
#
# State: stored in existing devops-lab-tfstate-bucket
# Auth:  GitHub OIDC (same role as platform-foundation)
# Cost:  ~$0–1/mo (S3 + CloudFront free tier covers
#        personal traffic volumes entirely)
###############################################

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "devops-lab-tfstate-bucket"
    key          = "onwua-portfolio/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"
}

# ACM must be in us-east-1 for CloudFront — this is already our region
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

###############################################
# Data: existing Route53 hosted zone for onwua.com
# Create this manually first if it doesn't exist:
#   aws route53 create-hosted-zone --name onwua.com --caller-reference $(date +%s)
###############################################
data "aws_route53_zone" "onwua" {
  name         = "onwua.com."
  private_zone = false
}

###############################################
# S3 Bucket — private origin (CloudFront only)
# No public access — CloudFront OAC handles serving
###############################################
resource "aws_s3_bucket" "portfolio" {
  bucket = "onwua-portfolio-site"

  tags = {
    Project = "onwua-portfolio"
    Env     = "prod"
  }
}

resource "aws_s3_bucket_versioning" "portfolio" {
  bucket = aws_s3_bucket.portfolio.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "portfolio" {
  bucket = aws_s3_bucket.portfolio.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

###############################################
# CloudFront Origin Access Control (OAC)
# Modern replacement for OAI — required for
# private S3 origins with CloudFront
###############################################
resource "aws_cloudfront_origin_access_control" "portfolio" {
  name                              = "onwua-portfolio-oac"
  description                       = "OAC for onwua.com portfolio S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

###############################################
# S3 Bucket Policy — allow CloudFront OAC only
###############################################
resource "aws_s3_bucket_policy" "portfolio" {
  bucket = aws_s3_bucket.portfolio.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.portfolio.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.portfolio.arn
          }
        }
      }
    ]
  })
}

###############################################
# ACM Certificate — onwua.com + www.onwua.com
# DNS validated — Terraform manages the records
###############################################
resource "aws_acm_certificate" "portfolio" {
  provider          = aws.us_east_1
  domain_name       = "onwua.com"
  validation_method = "DNS"

  subject_alternative_names = [
    "www.onwua.com"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project = "onwua-portfolio"
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.portfolio.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.onwua.zone_id
}

resource "aws_acm_certificate_validation" "portfolio" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.portfolio.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

###############################################
# CloudFront Function — directory index rewrite
#
# Problem: default_root_object only applies to the bucket
# root ("/" -> index.html). Sub-paths like /projects/ are
# requested from S3 as the literal key "projects/", which
# does not exist (Hugo writes "projects/index.html"). This
# causes a 404-at-origin that surfaces to the browser as a
# 403 AccessDenied, because of how CloudFront+OAC handles a
# missing key against a private bucket.
#
# Fix: rewrite any request path ending in "/" (or with no
# file extension) to append index.html before CloudFront
# looks it up in S3. Runs on every request at the edge,
# before the cache lookup.
###############################################
resource "aws_cloudfront_function" "index_rewrite" {
  name    = "onwua-portfolio-index-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "Rewrite directory paths to index.html for Hugo clean URLs"
  publish = true
  code    = file("${path.module}/index-rewrite.js")
}

###############################################
# CloudFront Distribution
###############################################
resource "aws_cloudfront_distribution" "portfolio" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # US/Europe only — cheapest tier
  comment             = "onwua.com portfolio"

  aliases = ["onwua.com", "www.onwua.com"]

  # S3 origin — private bucket via OAC
  origin {
    domain_name              = aws_s3_bucket.portfolio.bucket_regional_domain_name
    origin_id                = "S3-onwua-portfolio"
    origin_access_control_id = aws_cloudfront_origin_access_control.portfolio.id
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-onwua-portfolio"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # Using managed cache policy: CachingOptimized
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    # Rewrites /foo/ -> /foo/index.html at the edge before cache lookup
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.index_rewrite.arn
    }
  }

  # Custom error pages — return index.html for 404s
  # (Hugo static sites need this for clean URLs)
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/404.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.portfolio.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Project = "onwua-portfolio"
  }
}

###############################################
# Route53 Records — apex + www → CloudFront
###############################################
resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.onwua.zone_id
  name    = "onwua.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.portfolio.domain_name
    zone_id                = aws_cloudfront_distribution.portfolio.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.onwua.zone_id
  name    = "www.onwua.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.portfolio.domain_name
    zone_id                = aws_cloudfront_distribution.portfolio.hosted_zone_id
    evaluate_target_health = false
  }
}

###############################################
# IAM Policy for GitHub Actions — portfolio deploy
# Attach to existing github-oidc-role in platform-foundation
###############################################
resource "aws_iam_policy" "portfolio_deploy" {
  name        = "onwua-portfolio-deploy-policy"
  description = "GitHub Actions permissions for onwua.com portfolio deploy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Deploy"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.portfolio.arn,
          "${aws_s3_bucket.portfolio.arn}/*"
        ]
      },
      {
        Sid    = "CloudFrontInvalidate"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation"
        ]
        Resource = aws_cloudfront_distribution.portfolio.arn
      }
    ]
  })
}
