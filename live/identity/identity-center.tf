# the Identity Center instance (organization instance in Zurich) was enabled by hand
data "aws_ssoadmin_instances" "this" {}

data "aws_organizations_organization" "this" {}

locals {
  instance_arn      = one(data.aws_ssoadmin_instances.this.arns)
  identity_store_id = one(data.aws_ssoadmin_instances.this.identity_store_ids)

  # account name -> ID, the management account under the fixed key "management"
  accounts = merge(
    {
      for account in data.aws_organizations_organization.this.non_master_accounts :
      account.name => account.id if account.state == "ACTIVE"
    },
    { management = data.aws_organizations_organization.this.master_account_id },
  )

  email_parts = split("@", var.account_email_base)
}

resource "aws_identitystore_group" "this" {
  for_each = {
    Platform   = "Platform team: admin in all accounts"
    Developers = "Workload developers: admin in dev, read-only in prod"
    ReadOnly   = "Read-only in all accounts"
    Billing    = "Billing and cost in the management account"
  }

  identity_store_id = local.identity_store_id
  display_name      = each.key
  description       = each.value
}

# the admin user created by hand joins Platform
data "aws_identitystore_user" "admin" {
  identity_store_id = local.identity_store_id

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = var.admin_user_name
    }
  }
}

# demo user for "admin in dev, read-only in prod" (password set in the console)
resource "aws_identitystore_user" "developer" {
  identity_store_id = local.identity_store_id
  user_name         = "developer"
  display_name      = "Demo Developer"

  name {
    given_name  = "Demo"
    family_name = "Developer"
  }

  emails {
    value   = "${local.email_parts[0]}+developer@${local.email_parts[1]}"
    primary = true
  }
}

resource "aws_identitystore_group_membership" "this" {
  for_each = {
    admin     = { group = "Platform", user_id = data.aws_identitystore_user.admin.user_id }
    developer = { group = "Developers", user_id = aws_identitystore_user.developer.user_id }
  }

  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.this[each.value.group].group_id
  member_id         = each.value.user_id
}
