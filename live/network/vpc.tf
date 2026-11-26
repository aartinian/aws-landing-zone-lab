# one shared VPC (like ACPM): dev subnets in the primary CIDR from the nonprod pool, prod
# subnets in a secondary CIDR from the prod pool. Private only: no internet or NAT gateway.
resource "aws_vpc" "this" {
  # checkov:skip=CKV2_AWS_11: no flow logs yet, next step is delivery to the log-archive bucket
  provider = aws.network

  ipv4_ipam_pool_id    = aws_vpc_ipam_pool.env["nonprod"].id
  ipv4_netmask_length  = 22
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "shared" }

  depends_on = [aws_vpc_ipam_pool_cidr.env]
}

resource "aws_vpc_ipv4_cidr_block_association" "prod" {
  provider = aws.network

  vpc_id              = aws_vpc.this.id
  ipv4_ipam_pool_id   = aws_vpc_ipam_pool.env["prod"].id
  ipv4_netmask_length = 22

  depends_on = [aws_vpc_ipam_pool_cidr.env]
}

# no rules: every workload brings its own security groups
resource "aws_default_security_group" "this" {
  provider = aws.network

  vpc_id = aws_vpc.this.id
}

locals {
  # zone IDs, not names: the same physical AZ in every account (names are shuffled per account)
  azs = ["euc2-az1", "euc2-az2"]

  # "dev-0" -> /24 in AZ a, ... (2 AZs per environment, the rest of each /22 stays free)
  subnets = merge([
    for env, cidr in {
      dev  = aws_vpc.this.cidr_block
      prod = aws_vpc_ipv4_cidr_block_association.prod.cidr_block
      } : {
      for i in range(2) : "${env}-${i}" => {
        env  = env
        az   = local.azs[i]
        cidr = cidrsubnet(cidr, 2, i)
      }
    }
  ]...)
}

resource "aws_subnet" "this" {
  for_each = local.subnets
  provider = aws.network

  vpc_id               = aws_vpc.this.id
  availability_zone_id = each.value.az
  cidr_block           = each.value.cidr

  # participants don't see these tags (owner-side only)
  tags = { Name = "shared-${each.key}" }
}
