# GitHub Actions authenticates with short-lived OIDC tokens: no stored AWS keys.
# two roles with different trust:
#   plan  -> pull requests (read-only + state lock)
#   apply -> only jobs in the protected GitHub environment (required reviewer)

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

locals {
  # GitHub sends immutable subject claims: owner and repo carry their numeric IDs,
  # so a deleted and re-created repo with the same name cannot assume the roles
  sub_prefix = join("", [
    "repo:${var.github_owner}@${var.github_owner_id}",
    "/${var.github_repo}@${var.github_repo_id}",
  ])
  oidc_host  = "token.actions.githubusercontent.com"
  plan_subs  = ["${local.sub_prefix}:pull_request"]
  apply_subs = ["${local.sub_prefix}:environment:${var.github_apply_environment}"]
  state_arn  = aws_s3_bucket.state.arn
}

data "aws_iam_policy_document" "trust" {
  for_each = {
    plan  = local.plan_subs
    apply = local.apply_subs
  }

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    # exact match on the subject: this repo, and only PRs or the protected environment
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = each.value
    }
  }
}

# plan role
resource "aws_iam_role" "plan" {
  name                 = "${var.name_prefix}-github-plan"
  description          = "GitHub Actions: terraform plan on pull requests"
  assume_role_policy   = data.aws_iam_policy_document.trust["plan"].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# plan needs to read state and write only the lock file (<key>.tflock)
data "aws_iam_policy_document" "plan_state" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [local.state_arn]
  }
  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = ["${local.state_arn}/*"]
  }
  statement {
    sid       = "LockFileOnly"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_arn}/*.tflock"]
  }
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "terraform-state-read-and-lock"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_state.json
}

# apply role
resource "aws_iam_role" "apply" {
  name                 = "${var.name_prefix}-github-apply"
  description          = "GitHub Actions: terraform apply from the protected environment"
  assume_role_policy   = data.aws_iam_policy_document.trust["apply"].json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "apply_admin" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
