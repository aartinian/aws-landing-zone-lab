variable "region" {
  description = "Region of the Identity Center instance."
  type        = string
  default     = "eu-central-2"
}

variable "admin_user_name" {
  description = "User name of the existing Identity Center admin user, added to Platform."
  type        = string
  sensitive   = true
}

variable "account_email_base" {
  description = "Base email, e.g. you@example.com. The demo user gets you+developer@example.com."
  type        = string
  sensitive   = true
}
