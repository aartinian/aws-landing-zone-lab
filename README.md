# aws-landing-zone-lab

A small, multi-account AWS landing zone built with Terraform and GitHub Actions, in the Zurich Region (eu-central-2). It is a personal lab to practice platform engineering: account vending, guardrails, identity, central logging, and a pipeline with a manual approval for production.

## Target design

```
Organization (management account: billing, Organizations, Identity Center)
├── Security OU
│   ├── log-archive        org CloudTrail, Config, access logs
│   └── security-tooling   delegated admin: GuardDuty, Security Hub, IAM Access Analyzer
├── Workloads OU
│   ├── workload-dev
│   └── workload-prod
├── Sandbox OU             empty; used to test SCPs
└── Suspended OU           empty; quarantine for closed accounts
```

Guardrails: Zurich-only region SCP (global services exempt), deny leaving the organization, deny root user, protect security services, tag policy.

Workload: a small Python Lambda that ingests MeteoSwiss open data, deployed dev → prod through the pipeline.

## Layout

| Path | Content | Status |
|---|---|---|
| `bootstrap/` | Budget, state bucket, GitHub OIDC roles. Applied manually once. | applied |
| `modules/` | Reusable modules | in use |
| `live/` | Root modules per component, one state key each | in use |
| `workloads/` | Application code (Python), tested in the pipeline, deployed by `live/workload-*` | in use |
| `.github/` | Pipeline: plan on PR, apply on merge with approval | ready |

## Pipeline

[`.github/workflows/terraform.yaml`](.github/workflows/terraform.yaml), for every root module in `live/<component>/`:

| Event | Role (OIDC, no keys) | Steps |
|---|---|---|
| Pull request | `awslab-github-plan`: read-only | `fmt`, ruff + pytest, `validate`, `plan` |
| Merge to `master` | `awslab-github-apply`: admin, only in environment `prod` | tests pass, waits for approval, then `plan` and `apply` |

- Logs are public: the management account ID and all member account IDs and emails are masked before Terraform runs. Plans are not posted as PR comments.
- Actions are pinned to commit SHAs; Dependabot updates them weekly.
- `bootstrap/` is applied by hand and not part of the pipeline.

## Conventions

- Region `eu-central-2` only. Exception: the Well-Architected Tool (not available in Zurich) runs in eu-central-1.
- Required tags: `project`, `env`, `owner`, `data-classification`, `managed-by`.
- No account IDs, emails or state in Git: real values live in git-ignored `*.tfvars` / `backend.hcl` and in GitHub secrets.
- Costs: target < 5 USD/month; budget alert from day one.

## Code style

- **Comments** start lowercase (names and acronyms keep their case: AWS, GitHub, `use_lockfile`). A single sentence has no final period; several sentences each end with one.
- **Descriptions** (`description = "..."` in Terraform) are user-facing text: normal sentences.
- **Line length** 100 for `.tf`, `.yaml`, shell and Python. Exceptions: SHA-pinned `uses:` lines, URLs, ARNs.
- **Long commands** go one option per line with `\`, in a `run: |` block. Long HCL expressions move into `locals`.
- `.editorconfig` sets the ruler; `terraform fmt` and `actionlint` run before every commit.

## Teardown

Reverse order of creation. Filled in as components are added.

1. Workloads: `terraform destroy` per `live/` component (prod, then dev).
2. Security services and organization CloudTrail.
3. Identity Center assignments and permission sets.
4. SCPs and tag policies (detach, then delete).
5. Member accounts: close via Organizations (90-day post-closure period; they count against the account quota until then).
6. Bootstrap:
   - Empty the state bucket, **including all object versions and delete markers**.
   - Remove `prevent_destroy` from `aws_s3_bucket.state`, migrate state back to local (`terraform init -migrate-state` with the backend block commented out), then `terraform destroy`.
7. Check Cost Explorer and the Billing console the next day for leftovers.
