variable "name" {
  description = "Name of the Lambda function, its role, queues and security group."
  type        = string
  default     = "weather-parse"
}

variable "source_dir" {
  description = "Directory with the Python package (contains weather_parse/)."
  type        = string
}

variable "bucket_name" {
  description = "Bucket of weather-ingest: new files under smn/ trigger the summary."
  type        = string
}

variable "subnet_ids" {
  description = "Shared subnets the function runs in (owned by the network account)."
  type        = list(string)
}

variable "vpc_id" {
  description = "Shared VPC of the subnets, for the security group."
  type        = string
}

variable "s3_prefix_list_id" {
  description = "Managed prefix list of S3 in the Region: the only destination the function needs."
  type        = string
}

variable "log_retention_days" {
  description = "Days to keep the Lambda logs."
  type        = number
  default     = 14
}
