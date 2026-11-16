variable "region" {
  description = "Home Region of the lab."
  type        = string
  default     = "eu-central-2"
}

variable "member_role_name" {
  description = "Role assumed in the workload account. Pipeline plans use the read-only role."
  type        = string
  default     = "OrganizationAccountAccessRole"
}
