# account IDs from Organizations, tags from the vending file (single source of truth)
data "aws_organizations_organization" "this" {}

locals {
  vending = yamldecode(file("${path.module}/../organization/accounts.yaml"))

  account_ids = {
    for account in data.aws_organizations_organization.this.non_master_accounts :
    account.name => account.id if account.state == "ACTIVE"
  }

  role_arns = {
    for name, id in local.account_ids : name => "arn:aws:iam::${id}:role/${var.member_role_name}"
  }

  account_tags = {
    for name, account in local.vending : name => {
      owner               = account.owner
      env                 = account.env
      data-classification = account["data-classification"]
    }
  }

  common_tags = {
    project    = "aws-landing-zone-lab"
    component  = "account-baseline"
    managed-by = "terraform"
  }

  email_parts   = split("@", var.account_email_base)
  budget_emails = ["${local.email_parts[0]}+aws-budget@${local.email_parts[1]}"]

  # keep in sync with the module calls in baseline.tf
  baselined = ["log-archive", "security-tooling", "network", "workload-dev", "workload-prod"]
  missing   = setsubtract(keys(local.vending), local.baselined)
}

# warns in every plan if an account in accounts.yaml has no baseline yet
check "every_account_has_a_baseline" {
  assert {
    condition     = length(local.missing) == 0
    error_message = "No baseline for: ${join(", ", local.missing)}."
  }
}
