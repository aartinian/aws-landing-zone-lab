# account ID from Organizations, tags from the vending file (single source of truth)
data "aws_organizations_organization" "this" {}

locals {
  vending      = yamldecode(file("${path.module}/../organization/accounts.yaml"))
  account_name = "workload-dev"
  account      = local.vending[local.account_name]

  account_id = one([
    for account in data.aws_organizations_organization.this.non_master_accounts :
    account.id if account.name == local.account_name && account.state == "ACTIVE"
  ])

  account_tags = {
    owner               = local.account.owner
    env                 = local.account.env
    data-classification = local.account["data-classification"]
  }

  common_tags = {
    project    = "aws-landing-zone-lab"
    component  = "workload-dev"
    managed-by = "terraform"
  }
}

module "weather_ingest" {
  source = "../../modules/weather-ingest"

  providers = {
    aws = aws.workload
  }

  source_dir    = "${path.module}/../../workloads/weather-ingest/src"
  stations      = ["klo"]
  force_destroy = true
}
