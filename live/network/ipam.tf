# IPAM in the delegated admin account (network), Advanced tier: the Free tier has no private
# IPv4 pools. Billed per active IP in the operating Regions of the whole organization.
resource "aws_vpc_ipam" "this" {
  provider = aws.network

  description = "organization IPAM"
  tier        = "advanced"
  cascade     = true # destroy deletes the pools too (teardown after the interview)

  operating_regions {
    region_name = var.region
  }
}

# 2 levels: top pool -> one pool per environment. With a second Region, a Region level
# goes between them (the locale moves there).
resource "aws_vpc_ipam_pool" "top" {
  provider = aws.network

  description    = "all private addresses"
  address_family = "ipv4"
  ipam_scope_id  = aws_vpc_ipam.this.private_default_scope_id
}

resource "aws_vpc_ipam_pool_cidr" "top" {
  provider = aws.network

  ipam_pool_id = aws_vpc_ipam_pool.top.id
  cidr         = "10.0.0.0/8"
}

locals {
  env_cidrs = {
    nonprod = "10.0.0.0/12"
    prod    = "10.16.0.0/12"
  }
}

resource "aws_vpc_ipam_pool" "env" {
  for_each = local.env_cidrs
  provider = aws.network

  description         = each.key
  address_family      = "ipv4"
  ipam_scope_id       = aws_vpc_ipam.this.private_default_scope_id
  source_ipam_pool_id = aws_vpc_ipam_pool.top.id
  locale              = var.region # VPCs can only allocate from a pool with their Region

  # VPCs take a /22 to /16, nothing larger
  allocation_min_netmask_length = 16
  allocation_max_netmask_length = 22

  tags = { Name = each.key }
}

resource "aws_vpc_ipam_pool_cidr" "env" {
  for_each = local.env_cidrs
  provider = aws.network

  ipam_pool_id = aws_vpc_ipam_pool.env[each.key].id
  cidr         = each.value

  depends_on = [aws_vpc_ipam_pool_cidr.top]
}
