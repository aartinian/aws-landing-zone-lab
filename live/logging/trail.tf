# one trail for all accounts and Regions, created in the management account.
# Member accounts see it but cannot change or stop it.
resource "aws_cloudtrail" "organization" {
  name                          = var.trail_name
  s3_bucket_name                = aws_s3_bucket.logs.id
  is_organization_trail         = true
  is_multi_region_trail         = true # also records denied calls outside Zurich
  include_global_service_events = true # IAM, STS, sign-in (logged in us-east-1)
  enable_log_file_validation    = true # signed digest files prove logs were not changed

  lifecycle {
    precondition {
      condition = contains(
        data.aws_organizations_organization.this.aws_service_access_principals,
        "cloudtrail.amazonaws.com",
      )
      error_message = "Enable trusted access for CloudTrail first (live/organization)."
    }
  }

  # CloudTrail checks the bucket policy when the trail is created
  depends_on = [aws_s3_bucket_policy.logs]
}
