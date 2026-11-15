# outputs for the bootstrap resources: state bucket, GitHub OIDC roles, and budget

output "state_bucket_name" {
  description = "Put into backend.hcl (git-ignored) for every root module."
  value       = aws_s3_bucket.state.bucket
}

output "github_plan_role_arn" {
  description = "GitHub repository secret AWS_PLAN_ROLE_ARN."
  value       = aws_iam_role.plan.arn
}

output "github_apply_role_arn" {
  description = "GitHub environment secret AWS_APPLY_ROLE_ARN (environment: prod)."
  value       = aws_iam_role.apply.arn
}

output "budget_name" {
  value = aws_budgets_budget.monthly.name
}
