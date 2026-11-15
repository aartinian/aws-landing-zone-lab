# bootstrap

The one root module that runs **manually, with local credentials**: it creates what the pipeline needs before the pipeline can exist. Everything after it runs through GitHub Actions.

| Resource | Why |
|---|---|
| Budget, 5 USD/month, alerts at 50 % / 100 % actual and 100 % forecast | Cost guardrail first. In the payer account it covers all member accounts. |
| S3 state bucket (versioned, SSE-S3, TLS-only, Block Public Access, no ACLs, old versions expire) | Remote state for every root module. S3-native locking (`use_lockfile`), no DynamoDB table. |
| Account-level S3 Block Public Access | Management account baseline. |
| IAM OIDC provider for GitHub | Pipeline uses short-lived tokens, no stored access keys. |
| Role `awslab-github-plan` | Trust: pull requests of this repo only. ReadOnlyAccess + state read + lock file write. |
| Role `awslab-github-apply` | Trust: jobs in the GitHub environment `prod` only (required reviewer). AdministratorAccess for now; narrow later. |

## Prerequisites

1. **Enable Zurich (eu-central-2)** in the management account: Console › Account › AWS Regions › Europe (Zurich) › Enable. Opt-in Regions take a few minutes. Member accounts are enabled later by the vending module.
2. **Credentials:** the Identity Center admin user in the management account, profile `lab-management` (`aws sso login --profile lab-management`, then `export AWS_PROFILE=lab-management`). Never the root user.
3. Terraform >= 1.10.

## Bootstrap order

```sh
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # fill in; git-ignored

# 1. First apply with local state
terraform init
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan

# 2. Move the state into the bucket it just created
terraform output -raw state_bucket_name         # -> backend.hcl
cp backend.hcl.example backend.hcl              # set bucket; git-ignored
#    uncomment the backend block in backend.tf
terraform init -migrate-state -backend-config=backend.hcl
rm terraform.tfstate terraform.tfstate.backup   # after verifying the remote state

# 3. Store the outputs in GitHub (not in files)
#    repo secret            AWS_PLAN_ROLE_ARN   = github_plan_role_arn
#    env "prod" secret      AWS_APPLY_ROLE_ARN  = github_apply_role_arn
#    repo secret            TF_STATE_BUCKET     = state_bucket_name
```

## Notes

- **Opt-in Region and STS.** Tokens from the global STS endpoint are not valid in opt-in Regions by default. The pipeline uses the regional endpoint (`aws-region: eu-central-2` in `aws-actions/configure-aws-credentials`).
- **Bucket name** contains the account ID. It is computed at apply time and never committed.
- **`prevent_destroy`** on the state bucket: teardown removes it on purpose (see the root README › Teardown).
- **Why the apply role is admin:** it manages Organizations, SCPs and Identity Center from the management account. The trust policy (exact `sub` match on the protected environment) is the control. Narrowing it is follow-up work.
