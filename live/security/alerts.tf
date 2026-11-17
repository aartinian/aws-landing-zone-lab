# high-severity findings by email. GuardDuty and Security Hub send the findings of all
# accounts to EventBridge in the admin account (security-tooling), so one topic is enough.

locals {
  email_parts = split("@", var.account_email_base)

  # GuardDuty: severity 7+ (high, critical). Security Hub: new critical posture findings;
  # GuardDuty findings also arrive there and are skipped to avoid a second email.
  finding_rules = {
    guardduty = {
      description = "GuardDuty findings with severity high or critical."
      pattern = {
        source      = ["aws.guardduty"]
        detail-type = ["GuardDuty Finding"]
        detail      = { severity = [{ numeric = [">=", 7] }] }
      }
      input_paths = {
        account  = "$.detail.accountId"
        severity = "$.detail.severity"
        type     = "$.detail.type"
        title    = "$.detail.title"
      }
      template = "\"GuardDuty <severity> in <account>: <type>. <title>\""
    }
    securityhub = {
      description = "New critical Security Hub findings, except GuardDuty."
      pattern = {
        source      = ["aws.securityhub"]
        detail-type = ["Security Hub Findings - Imported"]
        detail = {
          findings = {
            ProductName = [{ anything-but = "GuardDuty" }]
            RecordState = ["ACTIVE"]
            Severity    = { Label = ["CRITICAL"] }
            Workflow    = { Status = ["NEW"] }
          }
        }
      }
      input_paths = {
        account = "$.detail.findings[0].AwsAccountId"
        control = "$.detail.findings[0].Compliance.SecurityControlId"
        title   = "$.detail.findings[0].Title"
      }
      template = "\"Security Hub CRITICAL in <account>: <control>. <title>\""
    }
  }
}

# a customer managed key would cost 1 USD/month; the AWS managed SNS key does not let
# EventBridge publish
resource "aws_sns_topic" "alerts" {
  # checkov:skip=CKV_AWS_26: no KMS, see the comment above
  provider = aws.security_tooling

  name = "security-alerts"
}

# AWS sends a confirmation email: the subscription stays pending until it is confirmed
resource "aws_sns_topic_subscription" "email" {
  provider = aws.security_tooling

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "${local.email_parts[0]}+aws-alerts@${local.email_parts[1]}"
}

resource "aws_cloudwatch_event_rule" "findings" {
  for_each = local.finding_rules
  provider = aws.security_tooling

  name          = "${each.key}-findings-to-email"
  description   = each.value.description
  event_pattern = jsonencode(each.value.pattern)
}

resource "aws_cloudwatch_event_target" "findings" {
  for_each = local.finding_rules
  provider = aws.security_tooling

  rule = aws_cloudwatch_event_rule.findings[each.key].name
  arn  = aws_sns_topic.alerts.arn

  input_transformer {
    input_paths    = each.value.input_paths
    input_template = each.value.template
  }
}

# only the two rules may publish
data "aws_iam_policy_document" "alerts" {
  statement {
    sid       = "EventBridgeRules"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [for rule in aws_cloudwatch_event_rule.findings : rule.arn]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  provider = aws.security_tooling

  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.alerts.json
}
