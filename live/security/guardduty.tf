# GuardDuty for the whole organization, administered from security-tooling.
# Order: detector in the admin account → delegated admin (management) → auto-enable all.

resource "aws_guardduty_detector" "admin" {
  provider = aws.security_tooling

  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES" # fast enough for alerting (A2)
}

resource "aws_guardduty_organization_admin_account" "this" {
  admin_account_id = local.admin_id

  depends_on = [aws_guardduty_detector.admin]
}

# ALL: GuardDuty creates and configures the detectors of member accounts. It only applies to
# accounts that are already members: existing accounts must be added once (see below).
resource "aws_guardduty_organization_configuration" "this" {
  provider = aws.security_tooling

  detector_id                      = aws_guardduty_detector.admin.id
  auto_enable_organization_members = "ALL"

  depends_on = [aws_guardduty_organization_admin_account.this]
}

locals {
  account_emails = {
    for account in data.aws_organizations_organization.this.accounts :
    account.id => account.email
  }

  # every account except the admin itself, management included
  guardduty_members = local.securityhub_members
}

# the management account must enable GuardDuty itself before it can be added as a member;
# the other accounts get their detector from the administrator
resource "aws_guardduty_detector" "management" {
  enable = true
}

# existing organization accounts: CreateMembers without an invitation, then auto-enable applies
resource "aws_guardduty_member" "this" {
  for_each = local.guardduty_members
  provider = aws.security_tooling

  detector_id = aws_guardduty_detector.admin.id
  account_id  = each.value
  email       = local.account_emails[each.value]
  invite      = false

  depends_on = [
    aws_guardduty_organization_configuration.this,
    aws_guardduty_detector.management,
  ]

  lifecycle {
    # the provider reads an enabled organization member as invite = true: no permanent diff
    ignore_changes = [invite]
  }
}

locals {
  # protection plans: on where the lab has matching resources (S3, Lambda) or where they
  # cost nothing without resources; off where they need agents or EC2
  guardduty_features = {
    S3_DATA_EVENTS         = true
    LAMBDA_NETWORK_LOGS    = true
    EKS_AUDIT_LOGS         = true
    RDS_LOGIN_EVENTS       = true
    EBS_MALWARE_PROTECTION = false # no EC2 in the lab
    RUNTIME_MONITORING     = false # needs agents
  }
}

resource "aws_guardduty_detector_feature" "admin" {
  for_each = local.guardduty_features
  provider = aws.security_tooling

  detector_id = aws_guardduty_detector.admin.id
  name        = each.key
  status      = each.value ? "ENABLED" : "DISABLED"
}

resource "aws_guardduty_organization_configuration_feature" "this" {
  for_each = local.guardduty_features
  provider = aws.security_tooling

  detector_id = aws_guardduty_detector.admin.id
  name        = each.key
  auto_enable = each.value ? "ALL" : "NONE"

  depends_on = [aws_guardduty_organization_configuration.this]
}
