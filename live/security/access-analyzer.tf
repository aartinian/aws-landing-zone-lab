# IAM Access Analyzer for the whole organization, administered from security-tooling.
# External access findings are free: anything shared outside the organization (the zone of
# trust) becomes a finding, e.g. a bucket policy or a role trust for another account.

resource "aws_organizations_delegated_administrator" "access_analyzer" {
  account_id        = local.admin_id
  service_principal = "access-analyzer.amazonaws.com"
}

resource "aws_accessanalyzer_analyzer" "organization" {
  provider = aws.security_tooling

  analyzer_name = "organization"
  type          = "ORGANIZATION"

  depends_on = [aws_organizations_delegated_administrator.access_analyzer]
}
