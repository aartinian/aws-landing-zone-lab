# live

Root modules, one state key each (`<component>/terraform.tfstate` in the bootstrap bucket).

| Component | Account | Content |
|---|---|---|
| `organization` | management | Organization (imported), OUs, accounts from `accounts.yaml` (tags, Zurich), member plan role via StackSet |
| `account-baseline` | each member account | `modules/account-baseline` per account: Block Public Access, EBS encryption, budget |
| `guardrails` | management | SCPs: baseline + Region restriction (root), deny-all (Suspended). Tag policy `tag-standard` (root) from `organization/tagging.yaml`: required tags + allowed values for S3 buckets, Lambda functions, log groups, the trail |
| `identity` | management | Identity Center: 4 groups, 3 permission sets, assignments, demo user |
| `logging` | management + log-archive | Organization trail (all accounts, all Regions, log file validation) → bucket in log-archive: Object Lock (governance, 30 days), versioned, 365-day expiry. Needs CloudTrail trusted access from `organization`. Config bucket for all accounts |
| `security` | management + all members | GuardDuty and Security Hub CSPM, delegated admin in security-tooling. `modules/security-baseline` per account: Config recorder (service-linked role) + Security Hub with FSBP only |
| `workload-dev`, `workload-prod` | workload accounts | `modules/weather-ingest`: dev ingests 1 station, prod 6. Applied in order dev → prod; prod is skipped if dev fails |
