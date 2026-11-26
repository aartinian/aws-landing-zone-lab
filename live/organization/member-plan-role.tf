# read-only role in every member account for "terraform plan" in pull requests.
# A service-managed StackSet deploys it to the OUs and, with auto-deployment,
# to every account created or moved there later. Suspended is excluded.

locals {
  member_plan_role_name = "awslab-terraform-plan"
  github_plan_role_arn = join("", [
    "arn:aws:iam::",
    data.aws_organizations_organization.current.master_account_id,
    ":role/awslab-github-plan",
  ])

  member_plan_role_template = {
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "Read-only role for terraform plan from GitHub Actions"
    Parameters = {
      TrustedRoleArn = { Type = "String" }
    }
    Resources = {
      PlanRole = {
        Type = "AWS::IAM::Role"
        Properties = {
          RoleName           = local.member_plan_role_name
          MaxSessionDuration = 3600
          ManagedPolicyArns  = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
          # tag policy compliance check of the provider, not part of ReadOnlyAccess
          Policies = [{
            PolicyName = "list-required-tags"
            PolicyDocument = {
              Version = "2012-10-17"
              Statement = [{
                Effect   = "Allow"
                Action   = "tag:ListRequiredTags"
                Resource = "*"
              }]
            }
          }]
          AssumeRolePolicyDocument = {
            Version = "2012-10-17"
            Statement = [{
              Effect    = "Allow"
              Principal = { AWS = { Ref = "TrustedRoleArn" } }
              Action    = "sts:AssumeRole"
            }]
          }
        }
      }
    }
  }
}

resource "aws_cloudformation_stack_set" "member_plan_role" {
  name             = "awslab-member-plan-role"
  description      = "Read-only role for terraform plan in member accounts"
  permission_model = "SERVICE_MANAGED"
  capabilities     = ["CAPABILITY_NAMED_IAM"]
  template_body    = jsonencode(local.member_plan_role_template)

  parameters = {
    TrustedRoleArn = local.github_plan_role_arn
  }

  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = false
  }

  lifecycle {
    # set by AWS for service-managed StackSets
    ignore_changes = [administration_role_arn]
  }
}

resource "aws_cloudformation_stack_set_instance" "member_plan_role" {
  stack_set_name            = aws_cloudformation_stack_set.member_plan_role.name
  stack_set_instance_region = var.region

  deployment_targets {
    organizational_unit_ids = [
      for name in ["Security", "Workloads", "Sandbox"] :
      aws_organizations_organizational_unit.this[name].id
    ]
  }
}

# separate instance for OUs added later: changing the OU list above would replace that
# instance, which deletes and recreates the plan role in every existing account
resource "aws_cloudformation_stack_set_instance" "member_plan_role_infrastructure" {
  stack_set_name            = aws_cloudformation_stack_set.member_plan_role.name
  stack_set_instance_region = var.region

  deployment_targets {
    organizational_unit_ids = [aws_organizations_organizational_unit.this["Infrastructure"].id]
  }
}
