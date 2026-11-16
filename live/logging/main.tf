# IDs from Organizations, tags from the vending file (single source of truth)
data "aws_organizations_organization" "this" {}

data "aws_caller_identity" "management" {}

locals {
  vending     = yamldecode(file("${path.module}/../organization/accounts.yaml"))
  log_archive = local.vending["log-archive"]

  log_archive_id = one([
    for account in data.aws_organizations_organization.this.non_master_accounts :
    account.id if account.name == "log-archive" && account.state == "ACTIVE"
  ])

  log_archive_tags = {
    owner               = local.log_archive.owner
    env                 = local.log_archive.env
    data-classification = local.log_archive["data-classification"]
  }

  common_tags = {
    project    = "aws-landing-zone-lab"
    component  = "logging"
    managed-by = "terraform"
  }

  organization_id = data.aws_organizations_organization.this.id
  management_id   = data.aws_caller_identity.management.account_id

  # built from its parts: the bucket policy needs it before the trail exists
  trail_arn = join(":", [
    "arn:aws:cloudtrail:${var.region}:${local.management_id}",
    "trail/${var.trail_name}",
  ])
}
