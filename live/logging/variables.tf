variable "region" {
  description = "Home Region of the lab. The trail and the log bucket live here."
  type        = string
  default     = "eu-central-2"
}

variable "member_role_name" {
  description = "Role assumed in the log-archive account. Pipeline plans use the read-only role."
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "trail_name" {
  description = "Name of the organization trail."
  type        = string
  default     = "awslab-org-trail"
}

variable "lock_days" {
  description = "Object Lock (governance mode): days a log file cannot be deleted or overwritten."
  type        = number
  default     = 30
}

variable "expiration_days" {
  description = "Days after which log files expire. Must be longer than the lock."
  type        = number
  default     = 365

  validation {
    condition     = var.expiration_days > var.lock_days
    error_message = "Logs must be kept longer than they are locked."
  }
}
