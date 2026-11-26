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
    component  = "network"
    managed-by = "terraform"
  }

  # environment -> participant account of its subnets
  participants = {
    dev  = "workload-dev"
    prod = "workload-prod"
  }
}
