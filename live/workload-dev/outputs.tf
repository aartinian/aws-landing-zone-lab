output "bucket_name" {
  description = "Bucket with the ingested files."
  value       = module.weather_ingest.bucket_name
}

output "function_name" {
  description = "Name of the ingest Lambda."
  value       = module.weather_ingest.function_name
}

output "parse_function_name" {
  description = "Name of the parse Lambda (runs in the shared VPC)."
  value       = module.weather_parse.function_name
}

output "parse_dlq_url" {
  description = "Dead-letter queue of the parse Lambda."
  value       = module.weather_parse.dlq_url
}
