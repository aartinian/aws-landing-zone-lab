# AWS Config: Security Hub CSPM evaluates most controls with Config rules

data "aws_region" "current" {}

# Security Hub control Config.1 expects the service-linked role (not a custom role)
resource "aws_iam_service_linked_role" "config" {
  aws_service_name = "config.amazonaws.com"
}

resource "aws_config_configuration_recorder" "this" {
  name     = "default"
  role_arn = aws_iam_service_linked_role.config.arn

  # all resource types except the compliance results of the Config rules themselves:
  # every control evaluation would otherwise be a paid configuration item
  recording_group {
    all_supported = false

    exclusion_by_resource_types {
      resource_types = ["AWS::Config::ResourceCompliance"]
    }

    recording_strategy {
      use_only = "EXCLUSION_BY_RESOURCE_TYPES"
    }
  }

  recording_mode {
    recording_frequency = "CONTINUOUS"
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = "default"
  s3_bucket_name = var.config_bucket_name

  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}
