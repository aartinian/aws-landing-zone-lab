# read by other components through terraform_remote_state

output "root_id" {
  value = local.root_id
}

output "ou_ids" {
  value = { for name, ou in aws_organizations_organizational_unit.this : name => ou.id }
}

output "account_ids" {
  value     = { for name, account in aws_organizations_account.this : name => account.id }
  sensitive = true
}

output "member_plan_role_name" {
  value = local.member_plan_role_name
}
