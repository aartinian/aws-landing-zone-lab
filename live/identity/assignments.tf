locals {
  all_accounts = keys(local.accounts)

  # group -> permission set -> accounts
  access = [
    { group = "Platform", permission_set = "AdministratorAccess", accounts = local.all_accounts },
    { group = "ReadOnly", permission_set = "ReadOnlyAccess", accounts = local.all_accounts },
    { group = "Developers", permission_set = "AdministratorAccess", accounts = ["workload-dev"] },
    { group = "Developers", permission_set = "ReadOnlyAccess", accounts = ["workload-prod"] },
    { group = "Billing", permission_set = "Billing", accounts = ["management"] },
  ]

  # one entry per group, permission set and account, keyed by names (stable for_each keys)
  assignments = merge([
    for entry in local.access : {
      for account in entry.accounts :
      "${entry.group}/${entry.permission_set}/${account}" => merge(entry, { account = account })
    }
  ]...)
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = local.assignments

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set].arn
  principal_type     = "GROUP"
  principal_id       = aws_identitystore_group.this[each.value.group].group_id
  target_type        = "AWS_ACCOUNT"
  target_id          = local.accounts[each.value.account]

  # the policy must be attached before the permission set is provisioned to an account
  depends_on = [aws_ssoadmin_managed_policy_attachment.this]
}
