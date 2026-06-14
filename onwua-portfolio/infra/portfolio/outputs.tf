output "cloudfront_domain" {
  description = "CloudFront distribution domain — use this to verify before DNS cutover"
  value       = aws_cloudfront_distribution.portfolio.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID — needed for cache invalidation in CI/CD"
  value       = aws_cloudfront_distribution.portfolio.id
}

output "s3_bucket_name" {
  description = "S3 bucket name — used in GitHub Actions workflow"
  value       = aws_s3_bucket.portfolio.id
}

output "site_url" {
  value = "https://onwua.com"
}
