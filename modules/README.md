# modules

Reusable modules, added step by step:

| Module | Purpose | Used by |
|---|---|---|
| `account-baseline` | Per-account defaults: S3 Block Public Access, EBS default encryption, budget | `live/account-baseline` |
| `weather-ingest` | Python Lambda that stores MeteoSwiss SwissMetNet open data in S3 (checksum verified), daily EventBridge schedule, least-privilege roles | `live/workload-dev`, `live/workload-prod` |
| `security-baseline` | Per-account AWS Config recorder (service-linked role, central bucket) and Security Hub CSPM with the FSBP standard | `live/security` |
