output "trail_arn" {
  description = "ARN of the organization trail."
  value       = aws_cloudtrail.organization.arn
}

output "log_bucket_name" {
  description = "Central CloudTrail bucket in the log-archive account."
  value       = aws_s3_bucket.logs.id
}
