# the same baseline in every member account (add a block per new account)

module "log_archive" {
  source        = "../../modules/account-baseline"
  providers     = { aws = aws.log_archive }
  account_name  = "log-archive"
  budget_emails = local.budget_emails
}

module "security_tooling" {
  source        = "../../modules/account-baseline"
  providers     = { aws = aws.security_tooling }
  account_name  = "security-tooling"
  budget_emails = local.budget_emails
}

module "network" {
  source        = "../../modules/account-baseline"
  providers     = { aws = aws.network }
  account_name  = "network"
  budget_emails = local.budget_emails
}

module "workload_dev" {
  source        = "../../modules/account-baseline"
  providers     = { aws = aws.workload_dev }
  account_name  = "workload-dev"
  budget_emails = local.budget_emails
}

module "workload_prod" {
  source        = "../../modules/account-baseline"
  providers     = { aws = aws.workload_prod }
  account_name  = "workload-prod"
  budget_emails = local.budget_emails
}
