# Security Hub CSPM with only the FSBP standard. "Default standards" would also add
# CIS v1.2.0 and roughly double the paid checks.
resource "aws_securityhub_account" "this" {
  enable_default_standards  = false
  control_finding_generator = "SECURITY_CONTROL" # one finding per control, not per standard
  auto_enable_controls      = true
}

resource "aws_securityhub_standards_subscription" "fsbp" {
  standards_arn = join("", [
    "arn:aws:securityhub:${data.aws_region.current.region}::",
    "standards/aws-foundational-security-best-practices/v/1.0.0",
  ])

  # controls need the recorder; without it they report "no data"
  depends_on = [aws_securityhub_account.this, aws_config_configuration_recorder_status.this]
}
