# management account: looks up the workload account ID in Organizations
provider "aws" {
  region = var.region

  default_tags {
    tags = merge(local.common_tags, { env = "management", owner = "platform" })
  }
}

# workload account: everything in this component is deployed here
provider "aws" {
  alias  = "workload"
  region = var.region

  assume_role {
    role_arn     = "arn:aws:iam::${local.account_id}:role/${var.member_role_name}"
    session_name = "terraform-workload-dev"
  }

  default_tags {
    tags = merge(local.common_tags, local.account_tags)
  }
}
