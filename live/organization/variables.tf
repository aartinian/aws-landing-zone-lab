variable "region" {
  description = "Home Region of the lab. It is enabled in every member account."
  type        = string
  default     = "eu-central-2"
}

variable "account_email_base" {
  description = "Base email, e.g. you@example.com. Accounts get you+<name>@example.com."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[^@+]+@[^@]+$", var.account_email_base))
    error_message = "Must be a plain email address without a +tag."
  }
}
