# SCPs never apply to the management account, only to member accounts.
# At most 5 SCPs per target (FullAWSAccess is one), so related rules share one policy.

data "aws_iam_policy_document" "baseline" {
  statement {
    sid       = "DenyLeaveOrganization"
    effect    = "Deny"
    actions   = ["organizations:LeaveOrganization"]
    resources = ["*"]
  }

  statement {
    sid       = "DenyRegionOptInChanges"
    effect    = "Deny"
    actions   = ["account:EnableRegion", "account:DisableRegion"]
    resources = ["*"]
  }

  # long-term root credentials are denied. Privileged root tasks (unlock a bucket policy,
  # delete root credentials) run as short AssumeRoot sessions from the management account,
  # limited by an AWS task policy (live/organization/root-access.tf).
  statement {
    sid       = "DenyRootUser"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::*:root"]
    }

    # the key only exists in AssumeRoot sessions
    condition {
      test     = "Null"
      variable = "aws:AssumedRoot"
      values   = ["true"]
    }
  }

  statement {
    sid    = "ProtectSecurityServices"
    effect = "Deny"
    actions = [
      "access-analyzer:DeleteAnalyzer",
      "cloudtrail:DeleteTrail",
      "cloudtrail:PutEventSelectors",
      "cloudtrail:StopLogging",
      "cloudtrail:UpdateTrail",
      "config:DeleteConfigurationRecorder",
      "config:DeleteDeliveryChannel",
      "config:StopConfigurationRecorder",
      "guardduty:DeleteDetector",
      "guardduty:DisassociateFromAdministratorAccount",
      "guardduty:DisassociateFromMasterAccount",
      "guardduty:StopMonitoringMembers",
      "securityhub:DisableSecurityHub",
      "securityhub:DisassociateFromAdministratorAccount",
      "securityhub:DisassociateFromMasterAccount",
    ]
    resources = ["*"]

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values   = [local.deploy_role_arn]
    }
  }
}

resource "aws_organizations_policy" "baseline" {
  name        = "baseline"
  description = "Deny leaving the org, Region changes, root user, disabling security services"
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.baseline.minified_json
}

resource "aws_organizations_policy_attachment" "baseline" {
  policy_id = aws_organizations_policy.baseline.id
  target_id = local.root_id
}
