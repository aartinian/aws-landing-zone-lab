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
