# backend configuration for Terraform state storage in S3
# note: to be enabled after initial local apply
terraform {
  backend "s3" {
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-central-2"
    encrypt      = true
    use_lockfile = true # S3-native locking, no DynamoDB table
  }
}
