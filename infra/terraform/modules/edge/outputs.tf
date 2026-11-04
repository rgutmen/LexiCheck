output "distribution_id" {
  value = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  value = aws_cloudfront_distribution.this.arn
}

output "domain_name" {
  value = aws_cloudfront_distribution.this.domain_name
}

output "site_bucket" {
  value = aws_s3_bucket.site.bucket
}

output "site_bucket_arn" {
  value = aws_s3_bucket.site.arn
}
