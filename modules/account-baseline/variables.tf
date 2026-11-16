variable "account_name" {
  description = "Name of the member account, used in resource names."
  type        = string
}

variable "budget_usd" {
  description = "Monthly cost budget of the account in USD."
  type        = number
  default     = 2
}

variable "budget_emails" {
  description = "Recipients of the budget alerts."
  type        = list(string)
  sensitive   = true
}
