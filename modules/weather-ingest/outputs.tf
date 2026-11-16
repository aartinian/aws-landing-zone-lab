output "bucket_name" {
  description = "Bucket with the ingested files."
  value       = aws_s3_bucket.data.id
}

output "function_name" {
  description = "Name of the ingest Lambda."
  value       = aws_lambda_function.this.function_name
}

output "schedule_name" {
  description = "Name of the daily schedule."
  value       = aws_scheduler_schedule.daily.name
}
