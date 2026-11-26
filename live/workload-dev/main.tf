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

  # owner of the shared VPC: its subnets are found by owner, the owner's tags are not shared
  network_id = one([
    for account in data.aws_organizations_organization.this.non_master_accounts :
    account.id if account.name == "network" && account.state == "ACTIVE"
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

# shared dev subnets from the network account (live/network, RAM share subnets-dev)
data "aws_subnets" "shared" {
  provider = aws.workload

  filter {
    name   = "owner-id"
    values = [local.network_id]
  }
}

data "aws_subnet" "shared" {
  provider = aws.workload
  id       = data.aws_subnets.shared.ids[0]
}

data "aws_ec2_managed_prefix_list" "s3" {
  provider = aws.workload
  name     = "com.amazonaws.${var.region}.s3"
}

module "weather_parse" {
  source = "../../modules/weather-parse"

  providers = {
    aws = aws.workload
  }

  source_dir        = "${path.module}/../../workloads/weather-parse/src"
  bucket_name       = module.weather_ingest.bucket_name
  subnet_ids        = data.aws_subnets.shared.ids
  vpc_id            = data.aws_subnet.shared.vpc_id
  s3_prefix_list_id = data.aws_ec2_managed_prefix_list.s3.id
}
