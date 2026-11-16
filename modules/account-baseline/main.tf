# what every member account gets, applied through the provider passed in by the caller

# no public buckets anywhere in the account, whatever a bucket policy says
resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# new EBS volumes and snapshots are encrypted (per Region, here the provider Region)
resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

# alert the owner when the account spends more than expected
resource "aws_budgets_budget" "monthly" {
  name         = "${var.account_name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_emails
  }
}
