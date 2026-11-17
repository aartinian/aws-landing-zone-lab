variable "region" {
  description = "Home Region of the lab. GuardDuty, Security Hub and Config run only here."
  type        = string
  default     = "eu-central-2"
}

variable "member_role_name" {
  description = "Role assumed in member accounts. Pipeline plans use the read-only role."
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "account_email_base" {
  description = "Base email, e.g. you@example.com. Alerts go to you+aws-alerts@example.com."
  type        = string
  sensitive   = true
}
