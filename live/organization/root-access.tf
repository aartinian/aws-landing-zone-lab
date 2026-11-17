# centralized root access: member accounts need no root credentials. Root tasks run as
# short sts:AssumeRoot sessions from the management account, each limited to one AWS task
# policy (e.g. S3UnlockBucketPolicy, IAMDeleteRootUserCredentials). New accounts are created
# without root credentials; existing ones are cleaned up by hand (see README).
resource "aws_iam_organizations_features" "this" {
  enabled_features = [
    "RootCredentialsManagement",
    "RootSessions",
  ]

  # needs trusted access for iam.amazonaws.com
  depends_on = [aws_organizations_organization.this]
}
