output "guardduty_detector_id" {
  description = "GuardDuty detector of the delegated admin (security-tooling)."
  value       = aws_guardduty_detector.admin.id
}

output "securityhub_members" {
  description = "Accounts that report to the Security Hub admin."
  value       = sort(keys(aws_securityhub_member.this))
}
