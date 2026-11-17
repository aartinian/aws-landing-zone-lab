# management account: reads the organization
provider "aws" {
  region = var.region

  default_tags {
    tags = merge(local.common_tags, {
      env                 = "management"
      owner               = "platform"
      data-classification = "internal"
    })
  }
}

# one provider per member account (Terraform cannot create providers in a loop)

provider "aws" {
  alias  = "log_archive"
  region = var.region

  assume_role {
    role_arn     = local.role_arns["log-archive"]
    session_name = "terraform-account-baseline"
  }

  default_tags {
    tags = merge(local.common_tags, local.account_tags["log-archive"])
  }
}

provider "aws" {
  alias  = "security_tooling"
  region = var.region

  assume_role {
    role_arn     = local.role_arns["security-tooling"]
    session_name = "terraform-account-baseline"
  }

  default_tags {
    tags = merge(local.common_tags, local.account_tags["security-tooling"])
  }
}

provider "aws" {
  alias  = "workload_dev"
  region = var.region

  assume_role {
    role_arn     = local.role_arns["workload-dev"]
    session_name = "terraform-account-baseline"
  }

  default_tags {
    tags = merge(local.common_tags, local.account_tags["workload-dev"])
  }
}

provider "aws" {
  alias  = "workload_prod"
  region = var.region

  assume_role {
    role_arn     = local.role_arns["workload-prod"]
    session_name = "terraform-account-baseline"
  }

  default_tags {
    tags = merge(local.common_tags, local.account_tags["workload-prod"])
  }
}
