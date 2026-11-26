# the ENI proof is replaced by weather-parse (live/workload-dev), a Lambda in the shared dev
# subnets. The provider stays until the proof is destroyed: Terraform needs it for the destroy.
# shortcut: remove this provider block (providers.tf) in the next PR
