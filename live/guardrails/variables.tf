variable "region" {
  description = "Region of the AWS provider."
  type        = string
  default     = "eu-central-2"
}

variable "allowed_regions" {
  description = "Regions member accounts may use. Global services are exempt."
  type        = list(string)
  default     = ["eu-central-2"]
}
