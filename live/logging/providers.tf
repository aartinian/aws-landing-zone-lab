# management account: owns the organization trail
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

# log-archive account: owns the log bucket, so admins in the management account
# or in workload accounts cannot delete the evidence of what they did
provider "aws" {
  alias  = "log_archive"
  region = var.region

  assume_role {
    role_arn     = "arn:aws:iam::${local.log_archive_id}:role/${var.member_role_name}"
    session_name = "terraform-logging"
  }

  default_tags {
    tags = merge(local.common_tags, local.log_archive_tags)
  }
}
