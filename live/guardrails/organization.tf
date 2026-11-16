# look up root and OUs by name instead of reading the organization state
data "aws_organizations_organization" "this" {}

data "aws_organizations_organizational_units" "root" {
  parent_id = local.root_id
}

locals {
  root_id = data.aws_organizations_organization.this.roots[0].id
  ou_ids = {
    for ou in data.aws_organizations_organizational_units.root.children : ou.name => ou.id
  }

  # the role the management account uses to deploy into member accounts
  # (exempt from the security-services protection)
  deploy_role_arn = "arn:aws:iam::*:role/OrganizationAccountAccessRole"
}
