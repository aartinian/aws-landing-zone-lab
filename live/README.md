# live

Root modules, one state key each (`<component>/terraform.tfstate` in the bootstrap bucket).

| Component | Account | Content |
|---|---|---|
| `organization` | management | Organization (imported), OUs, accounts from `accounts.yaml` (tags, Zurich), member plan role via StackSet |
| `account-baseline` | each member account | `modules/account-baseline` per account: Block Public Access, EBS encryption, budget |
| `guardrails` | management | SCPs: baseline + Region restriction (root), deny-all (Suspended); tag policy later |
| `identity` | management | Identity Center: 4 groups, 3 permission sets, assignments, demo user |
| `logging` | management + log-archive | Organization CloudTrail, log bucket |
| `workload-dev`, `workload-prod` | workload accounts | `modules/weather-ingest`: dev ingests 1 station, prod 6. Applied in order dev → prod; prod is skipped if dev fails |
