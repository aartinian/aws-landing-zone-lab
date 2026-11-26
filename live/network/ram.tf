# one share per environment: a principal sees every resource of its share
resource "aws_ram_resource_share" "subnets" {
  for_each = local.participants
  provider = aws.network

  name                      = "subnets-${each.key}"
  allow_external_principals = false # organization only, no invitation needed
}

resource "aws_ram_resource_association" "subnets" {
  for_each = aws_subnet.this
  provider = aws.network

  resource_arn       = each.value.arn
  resource_share_arn = aws_ram_resource_share.subnets[local.subnets[each.key].env].arn
}

resource "aws_ram_principal_association" "subnets" {
  for_each = local.participants
  provider = aws.network

  principal          = local.account_ids[each.value]
  resource_share_arn = aws_ram_resource_share.subnets[each.key].arn
}
