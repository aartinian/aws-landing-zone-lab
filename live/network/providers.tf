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

# network account: IPAM, VPC, RAM shares
provider "aws" {
  alias  = "network"
  region = var.region

  assume_role {
    role_arn     = local.role_arns["network"]
    session_name = "terraform-network"
  }

  default_tags {
    tags = merge(local.common_tags, local.account_tags["network"])
  }
}

# workload-dev: only to destroy the old ENI proof (participant.tf), remove in the next PR
provider "aws" {
  alias  = "workload_dev"
  region = var.region

  assume_role {
    role_arn     = local.role_arns["workload-dev"]
    session_name = "terraform-network"
  }

  default_tags {
    tags = merge(local.common_tags, local.account_tags["workload-dev"])
  }
}
