# aws-landing-zone-lab

A small, multi-account AWS landing zone built with Terraform and GitHub Actions, in the Zurich Region (eu-central-2). It is a personal lab to practice platform engineering: account vending, guardrails, identity, central logging, and a pipeline with a manual approval for production.

## Target design

```
Organization (management account: billing, Organizations, Identity Center)
├── Security OU
│   ├── log-archive        org CloudTrail, Config, access logs
│   └── security-tooling   delegated admin: GuardDuty, Security Hub, IAM Access Analyzer;
│                          high-severity findings by email
├── Infrastructure OU
│   └── network            IPAM (delegated admin), shared VPC: subnets shared through RAM
├── Workloads OU
│   ├── workload-dev       uses the shared dev subnets
│   └── workload-prod      uses the shared prod subnets
├── Sandbox OU             empty; used to test SCPs
└── Suspended OU           empty; quarantine for closed accounts
```

Guardrails: Zurich-only region SCP (global services exempt), deny leaving the organization, deny root user (short AssumeRoot task sessions from the management account excepted), protect security services, tag policy.

Workloads: a small Python Lambda that ingests MeteoSwiss open data, deployed dev → prod through the pipeline; in dev a second Lambda in the shared VPC summarizes each new file (S3 → SQS → Lambda).

## Layout

| Path | Content | Status |
|---|---|---|
| `bootstrap/` | Budget, state bucket, GitHub OIDC roles. Applied manually once. | applied |
| `modules/` | Reusable modules | in use |
| `live/` | Root modules per component, one state key each | in use |
| `workloads/` | Application code (Python), tested in the pipeline, deployed by `live/workload-*` | in use |
| `tools/` | Operations tools (Python, tested in the pipeline): [`org-inventory`](#organization-inventory), [`lab-tools`](tools/lab-tools/README.md) (accounts, subnets, untagged, findings) | in use |
| `.github/` | Pipeline: plan on PR, apply on merge with approval | ready |

## Pipeline

[`.github/workflows/terraform.yaml`](.github/workflows/terraform.yaml), for every root module in `live/<component>/`:

| Event | Role (OIDC, no keys) | Steps |
|---|---|---|
| Pull request | `awslab-github-plan`: read-only | `fmt`, tflint, Checkov, ruff + pytest, `validate`, `plan` |
| Merge to `master` | `awslab-github-apply`: admin, only in environment `prod` | tests pass, **one approval** for all roots, then `plan` and `apply` of each changed root in order (alphabetical, so `workload-dev` before `workload-prod`); stops at the first error |

- Logs are public: the management account ID and all member account IDs and emails are masked before Terraform runs. Plans are not posted as PR comments.
- Actions are pinned to commit SHAs; Dependabot updates them weekly.
- Static checks: [`.tflint.hcl`](.tflint.hcl) (Terraform and AWS rules) and [`.checkov.yaml`](.checkov.yaml) (security checks; `skip-check` is the list of accepted risks, each with its reason).
- Tag policy compliance: `TF_AWS_TAG_POLICY_COMPLIANCE=error` makes plan and apply fail if a resource misses a tag that the organization tag policy requires. The plan roles need `tag:ListRequiredTags`, which `ReadOnlyAccess` does not include.
- `bootstrap/` is applied by hand and not part of the pipeline.

## Organization inventory

`tools/org-inventory` checks every member account against the baseline and prints a Markdown table: OU and tags as in `accounts.yaml`, tag values from `tagging.yaml`, Zurich enabled, S3 Block Public Access, a budget, GuardDuty and Security Hub membership. Accounts in the organization but not in `accounts.yaml` are reported as drift. Read-only; exit code 1 if a check fails.

```bash
cd tools/org-inventory
uv run org-inventory --profile <management-profile> --output report.md
```

## Not built yet

Planned next steps, with the design decided:

| Topic | Plan |
|---|---|
| Inventory on a schedule | Run `org-inventory` weekly in GitHub Actions and write the report as job summary. Needs its own read-only OIDC role: the plan role only trusts pull requests. |
| Root credentials of existing accounts | Centralized root access is on, new accounts get no root credentials. Delete those of the existing members once with an `IAMDeleteRootUserCredentials` root session. |
| Fix after alert | Alerts go to email today. Next: a runbook per alert type, and fixes through the shared modules (e.g. KMS for the CloudTrail bucket, Security Hub CloudTrail.2). |
| Break-glass access | An IAM user with hardware MFA in the management account for when Identity Center is down, credentials kept offline, every sign-in alerts through the security topic. |
| Cost Anomaly Detection | A monitor per linked account with an email subscription, on top of the budgets. Free. |
| Resource control policy (RCP) | S3 only for principals of the organization. AWS service principals stay exempt (`aws:PrincipalIsAWSService`), otherwise CloudTrail and Config delivery break. Rollout on the Sandbox OU first. |
| Well-Architected review | Review of the weather-ingest workload, saved as a milestone. The tool is not in Zurich: it runs in eu-central-1 and stores only review answers (see Conventions). |

## Conventions

- Region `eu-central-2` only. Exception: the Well-Architected Tool (not available in Zurich) runs in eu-central-1.
- Required tags: `project`, `env`, `owner`, `data-classification`, `managed-by`. Allowed values for `env`, `owner` and `data-classification` are in [`live/organization/tagging.yaml`](live/organization/tagging.yaml), enforced by the tag policy in `live/guardrails`.
- No account IDs, emails or state in Git: real values live in git-ignored `*.tfvars` / `backend.hcl` and in GitHub secrets.
- Costs: target < 5 USD/month; budget alert from day one.

## Code style

- **Comments** start lowercase (names and acronyms keep their case: AWS, GitHub, `use_lockfile`). A single sentence has no final period; several sentences each end with one.
- **Descriptions** (`description = "..."` in Terraform) are user-facing text: normal sentences.
- **Line length** 100 for `.tf`, `.yaml`, shell and Python. Exceptions: SHA-pinned `uses:` lines, URLs, ARNs.
- **Long commands** go one option per line with `\`, in a `run: |` block. Long HCL expressions move into `locals`.
- `.editorconfig` sets the ruler; `terraform fmt` and `actionlint` run before every commit.

## Teardown

The pipeline applies every directory in `live/`: a root destroyed by hand comes back on the
next apply unless its directory is removed in the same step.

### Only the paid part (IPAM Advanced bills per active IP and hour)

1. PR: remove `module "weather_parse"`, the shared-subnet data sources and the parse outputs from
   `live/workload-dev`. The apply destroys the Lambda; Lambda deletes its network interfaces in
   the shared subnets, which can take up to 20 minutes.
2. By hand, with the apply credentials: `terraform -chdir=live/network destroy` (IPAM with its
   pools, VPC, subnets, RAM shares, S3 endpoint).
3. PR: delete `live/network/`, so the pipeline doesn't create it again. The `network` account and
   the IPAM delegated admin stay (free).

### Everything, reverse order of creation

1. Workloads: `live/workload-prod`, then `live/workload-dev`. The prod data bucket has
   `force_destroy = false`: empty it first (all versions). weather-parse first, see above.
2. Network: `live/network` (as above).
3. Account baseline: `live/account-baseline` (budgets, S3 public access block, ...).
4. Identity Center assignments and permission sets (`live/identity`).
5. Security services (`live/security`): `terraform destroy` disables Security Hub, Config, IAM Access Analyzer, the alert topic and the GuardDuty admin. Member detectors created by GuardDuty stay: delete them in each member account (`aws guardduty delete-detector`), they are not in the state (the management detector is).
6. Organization CloudTrail and log buckets (`live/logging`):
   - Destroy the trail first, so no new log files arrive.
   - The Config bucket has `prevent_destroy`: empty it (all versions), remove the flag, destroy.
   - The log bucket has Object Lock (governance) and `prevent_destroy`. Either wait until the last lock expires (30 days), or delete all object versions as admin with `--bypass-governance-retention`. Then remove `prevent_destroy` and destroy the bucket.
7. SCPs and tag policies (`live/guardrails`: detach, then delete).
8. Organization (`live/organization`): centralized root access first (destroy `aws_iam_organizations_features` before the trusted access for IAM is removed). Member accounts: remove `prevent_destroy`, close via Organizations (90-day post-closure period; they count against the account quota until then).
9. Bootstrap:
   - Empty the state bucket, **including all object versions and delete markers**.
   - Remove `prevent_destroy` from `aws_s3_bucket.state`, migrate state back to local (`terraform init -migrate-state` with the backend block commented out), then `terraform destroy`.
10. Check Cost Explorer and the Billing console the next day for leftovers.
