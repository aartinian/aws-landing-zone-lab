variable "region" {
  description = "Home Region of the lab."
  type        = string
  default     = "eu-central-2"
}

variable "member_role_name" {
  description = "Role assumed in member accounts. The pipeline uses the read-only role for plans."
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "account_email_base" {
  description = "Base email, e.g. you@example.com. Budget alerts go to you+aws-budget@example.com."
  type        = string
  sensitive   = true
}
