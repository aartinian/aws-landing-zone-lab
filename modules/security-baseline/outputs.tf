output "securityhub_enabled" {
  description = "Security Hub CSPM is enabled in this account (for depends_on in the root)."
  value       = aws_securityhub_account.this.id
}
