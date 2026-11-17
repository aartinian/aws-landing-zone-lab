# Config recorder + Security Hub CSPM (FSBP) in every account, including management.
# Explicit per account (like account-baseline) instead of Security Hub auto-enable, which
# would turn on the default standards (FSBP + CIS v1.2.0) and race with these resources.

module "management" {
  source = "../../modules/security-baseline"

  config_bucket_name = local.config_bucket_name
}

module "log_archive" {
  source    = "../../modules/security-baseline"
  providers = { aws = aws.log_archive }

  config_bucket_name = local.config_bucket_name
}

module "security_tooling" {
  source    = "../../modules/security-baseline"
  providers = { aws = aws.security_tooling }

  config_bucket_name = local.config_bucket_name
}

module "workload_dev" {
  source    = "../../modules/security-baseline"
  providers = { aws = aws.workload_dev }

  config_bucket_name = local.config_bucket_name
}

module "workload_prod" {
  source    = "../../modules/security-baseline"
  providers = { aws = aws.workload_prod }

  config_bucket_name = local.config_bucket_name
}
