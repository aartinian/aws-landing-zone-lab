# the organization was created by hand in the console, so it is imported, not created
data "aws_organizations_organization" "current" {}

import {
  to = aws_organizations_organization.this
  id = data.aws_organizations_organization.current.id
}

resource "aws_organizations_organization" "this" {
  feature_set = "ALL"

  # keep the account list (with emails) out of state and plan output
  return_organization_only = true

  # trusted access for services that act across the organization
  aws_service_access_principals = [
    "account.amazonaws.com",                             # enable Regions in member accounts
    "member.org.stacksets.cloudformation.amazonaws.com", # StackSets, activated by hand
    "sso.amazonaws.com",                                 # IAM Identity Center, enabled by hand
  ]

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
  ]
}

locals {
  root_id = aws_organizations_organization.this.roots[0].id

  # Sandbox and Suspended stay empty: one to test SCPs, one to park accounts before closing
  ous = toset(["Security", "Workloads", "Sandbox", "Suspended"])
}

resource "aws_organizations_organizational_unit" "this" {
  for_each = local.ous

  name      = each.key
  parent_id = local.root_id
}
