output "scp_ids" {
  value = {
    baseline = aws_organizations_policy.baseline.id
    region   = aws_organizations_policy.region.id
    deny_all = aws_organizations_policy.deny_all.id
  }
}

output "tag_policy_id" {
  value = aws_organizations_policy.tagging.id
}
