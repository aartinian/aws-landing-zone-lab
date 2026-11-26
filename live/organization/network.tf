# organization side of the network account (live/network): RAM sharing inside the
# organization, so subnets can be shared with accounts or OUs without invitations, and the
# network account as delegated administrator for VPC IPAM

resource "aws_ram_sharing_with_organization" "this" {
  # needs trusted access for ram.amazonaws.com
  depends_on = [aws_organizations_organization.this]
}

resource "aws_vpc_ipam_organization_admin_account" "this" {
  delegated_admin_account_id = aws_organizations_account.this["network"].id

  # IPAM runs in Zurich, which must be enabled in the account first
  depends_on = [aws_account_region.home]
}
