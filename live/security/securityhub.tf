# Security Hub CSPM, administered from security-tooling.
# Central configuration is not possible here: its home Region cannot be an opt-in
# Region such as Zurich. Local configuration + explicit members instead.

resource "aws_securityhub_organization_admin_account" "this" {
  admin_account_id = local.admin_id

  depends_on = [module.security_tooling]
}

# no auto-enable: every account gets Security Hub through baseline.tf (FSBP only)
resource "aws_securityhub_organization_configuration" "this" {
  provider = aws.security_tooling

  auto_enable           = false
  auto_enable_standards = "NONE"

  organization_configuration {
    configuration_type = "LOCAL"
  }

  depends_on = [aws_securityhub_organization_admin_account.this]
}

locals {
  securityhub_members = {
    management    = local.management_id
    log-archive   = local.account_ids["log-archive"]
    network       = local.account_ids["network"]
    workload-dev  = local.account_ids["workload-dev"]
    workload-prod = local.account_ids["workload-prod"]
  }
}

# organization accounts: no invitation, the admin sees their findings right away
resource "aws_securityhub_member" "this" {
  for_each = local.securityhub_members
  provider = aws.security_tooling

  account_id = each.value
  invite     = false

  depends_on = [
    aws_securityhub_organization_configuration.this,
    module.management,
    module.log_archive,
    module.network,
    module.workload_dev,
    module.workload_prod,
  ]
}
