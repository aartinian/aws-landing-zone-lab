variable "region" {
  description = "Home Region of the lab. Zurich is an opt-in Region: enable it in the account first."
  type        = string
  default     = "eu-central-2"
}

variable "management_account_id" {
  description = "ID of the management (payer) account. Only in terraform.tfvars, never committed."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "Must be a 12-digit AWS account ID."
  }
}

variable "name_prefix" {
  description = "Prefix for globally unique names (e.g. the state bucket)."
  type        = string
  default     = "awslab"
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget for the whole organization (the payer account sees all member accounts)."
  type        = number
  default     = 5
}

variable "budget_emails" {
  description = "Recipients of budget alerts. Only in terraform.tfvars, never committed."
  type        = list(string)

  validation {
    condition     = length(var.budget_emails) > 0
    error_message = "At least one email address is required."
  }
}

variable "github_owner" {
  description = "GitHub user or organization that owns the lab repository."
  type        = string
}

variable "github_repo" {
  description = "Name of the lab repository."
  type        = string
}

variable "github_apply_environment" {
  description = "GitHub environment whose jobs may assume the apply role (protected by a required reviewer)."
  type        = string
  default     = "prod"
}
