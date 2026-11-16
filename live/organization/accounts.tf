locals {
  accounts = {
    log-archive      = "Security"
    security-tooling = "Security"
    workload-dev     = "Workloads"
    workload-prod    = "Workloads"
  }

  # you@example.com -> you+<account>@example.com
  email_parts = split("@", var.account_email_base)
}

resource "aws_organizations_account" "this" {
  for_each = local.accounts

  name      = each.key
  email     = "${local.email_parts[0]}+${each.key}@${local.email_parts[1]}"
  parent_id = aws_organizations_organizational_unit.this[each.value].id

  # admin role in the new account, assumable from the management account
  role_name = "OrganizationAccountAccessRole"

  # destroy closes the account instead of only removing it from the organization
  close_on_deletion = true

  lifecycle {
    # closing an account is slow to undo (90-day post-closure period).
    # Remove this deliberately during teardown.
    prevent_destroy = true

    # only used at creation, AWS does not return them
    ignore_changes = [role_name, iam_user_access_to_billing]
  }
}

# Zurich is an opt-in Region and must be enabled in each account
# (also required before Identity Center can assign access there)
resource "aws_account_region" "home" {
  for_each = aws_organizations_account.this

  account_id  = each.value.id
  region_name = var.region
  enabled     = true

  depends_on = [aws_organizations_organization.this]
}
