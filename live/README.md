# live

Root modules, one state key each (`<component>/terraform.tfstate` in the bootstrap bucket). Planned:

| Component | Account | Content |
|---|---|---|
| `organization` | management | Organization, OUs, accounts, Region enablement |
| `guardrails` | management | SCPs, tag policy |
| `identity` | management | Identity Center permission sets and assignments |
| `logging` | management + log-archive | Organization CloudTrail, log bucket |
| `workload-dev`, `workload-prod` | workload accounts | Open-data Lambda |
