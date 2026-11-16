output "bucket_name" {
  description = "Bucket with the ingested files."
  value       = module.weather_ingest.bucket_name
}

output "function_name" {
  description = "Name of the ingest Lambda."
  value       = module.weather_ingest.function_name
}
