locals {
  permission_sets = {
    AdministratorAccess = {
      description = "Full access"
      session     = "PT1H"
      policy_arn  = "arn:aws:iam::aws:policy/AdministratorAccess"
    }
    ReadOnlyAccess = {
      description = "Read-only access"
      session     = "PT4H"
      policy_arn  = "arn:aws:iam::aws:policy/ReadOnlyAccess"
    }
    Billing = {
      description = "Billing and cost management"
      session     = "PT4H"
      policy_arn  = "arn:aws:iam::aws:policy/job-function/Billing"
    }
  }
}

# AdministratorAccess was created by hand together with the first user: import it
data "aws_ssoadmin_permission_set" "admin" {
  instance_arn = local.instance_arn
  name         = "AdministratorAccess"
}

import {
  to = aws_ssoadmin_permission_set.this["AdministratorAccess"]
  id = "${data.aws_ssoadmin_permission_set.admin.arn},${local.instance_arn}"
}

import {
  to = aws_ssoadmin_managed_policy_attachment.this["AdministratorAccess"]
  id = join(",", [
    local.permission_sets.AdministratorAccess.policy_arn,
    data.aws_ssoadmin_permission_set.admin.arn,
    local.instance_arn,
  ])
}

resource "aws_ssoadmin_permission_set" "this" {
  for_each = local.permission_sets

  instance_arn     = local.instance_arn
  name             = each.key
  description      = each.value.description
  session_duration = each.value.session
}

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  # checkov:skip=CKV_AWS_274: AdministratorAccess only for the Platform group, 1 hour sessions
  for_each = local.permission_sets

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
  managed_policy_arn = each.value.policy_arn
}
