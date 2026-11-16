# accounts parked before closing can do nothing
data "aws_iam_policy_document" "deny_all" {
  statement {
    sid       = "DenyAll"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_organizations_policy" "deny_all" {
  name        = "deny-all"
  description = "Deny everything, for the Suspended OU"
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.deny_all.minified_json
}

resource "aws_organizations_policy_attachment" "deny_all" {
  policy_id = aws_organizations_policy.deny_all.id
  target_id = local.ou_ids["Suspended"]
}
