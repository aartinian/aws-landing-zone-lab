locals {
  # account name -> { ou, owner, env, data-classification }
  accounts = yamldecode(file("${path.module}/accounts.yaml"))

  # allowed tag values (same file as the tag policy in live/guardrails)
  allowed = yamldecode(file("${path.module}/tagging.yaml")).tags

  # you@example.com -> you+<account>@example.com
  email_parts = split("@", var.account_email_base)
}

resource "aws_organizations_account" "this" {
  for_each = local.accounts

  name      = each.key
  email     = "${local.email_parts[0]}+${each.key}@${local.email_parts[1]}"
  parent_id = aws_organizations_organizational_unit.this[each.value.ou].id

  # account-level tags override the provider default tags with the same key
  tags = {
    owner               = each.value.owner
    env                 = each.value.env
    data-classification = each.value["data-classification"]
  }

  # admin role in the new account, assumable from the management account
  role_name = "OrganizationAccountAccessRole"

  # destroy closes the account instead of only removing it from the organization
  close_on_deletion = true

  lifecycle {
    precondition {
      condition     = contains(["dev", "prod"], each.value.env)
      error_message = "${each.key}: env must be dev or prod."
    }
    precondition {
      condition = contains(
        local.allowed["data-classification"],
        each.value["data-classification"],
      )
      error_message = join("", [
        "${each.key}: data-classification must be one of ",
        "${join(", ", local.allowed["data-classification"])} (tagging.yaml).",
      ])
    }
    precondition {
      condition     = contains(local.allowed.owner, each.value.owner)
      error_message = "${each.key}: owner must be one of ${join(", ", local.allowed.owner)}."
    }

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
