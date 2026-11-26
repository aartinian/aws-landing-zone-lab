# modules

Reusable modules, added step by step:

| Module | Purpose | Used by |
|---|---|---|
| `account-baseline` | Per-account defaults: S3 Block Public Access, EBS default encryption, budget | `live/account-baseline` |
| `weather-ingest` | Python Lambda that stores MeteoSwiss SwissMetNet open data in S3 (checksum verified), daily EventBridge schedule, least-privilege roles | `live/workload-dev`, `live/workload-prod` |
| `weather-parse` | New ingest file in S3 → SQS (dead-letter queue after 3 tries) → Lambda in the shared VPC (security group: HTTPS to S3 only, via the gateway endpoint) → `summary/<station>.json`; partial batch failures | `live/workload-dev` |
| `security-baseline` | Per-account AWS Config recorder (service-linked role, central bucket) and Security Hub CSPM with the FSBP standard | `live/security` |
