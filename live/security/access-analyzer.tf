# IAM Access Analyzer for the whole organization, administered from security-tooling.
# External access findings are free: anything shared outside the organization (the zone of
# trust) becomes a finding, e.g. a bucket policy or a role trust for another account.

resource "aws_organizations_delegated_administrator" "access_analyzer" {
  account_id        = local.admin_id
  service_principal = "access-analyzer.amazonaws.com"
}

# an organization analyzer needs the service-linked role in the management account as well
resource "aws_iam_service_linked_role" "access_analyzer" {
  aws_service_name = "access-analyzer.amazonaws.com"
}

# IAM is eventually consistent: CreateAnalyzer right after the role failed with the same error
resource "time_sleep" "access_analyzer_role" {
  create_duration = "30s"

  depends_on = [aws_iam_service_linked_role.access_analyzer]
}

resource "aws_accessanalyzer_analyzer" "organization" {
  provider = aws.security_tooling

  analyzer_name = "organization"
  type          = "ORGANIZATION"

  depends_on = [
    aws_organizations_delegated_administrator.access_analyzer,
    time_sleep.access_analyzer_role,
  ]
}
