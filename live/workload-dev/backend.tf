# bucket comes from -backend-config (GitHub secret TF_STATE_BUCKET or local backend.hcl)
terraform {
  backend "s3" {
    key          = "workload-dev/terraform.tfstate"
    region       = "eu-central-2"
    encrypt      = true
    use_lockfile = true
  }
}
