# AWS provider configuration for the bootstrap resources
provider "aws" {
  region = var.region

  # guard against running this with credentials for the wrong account
  allowed_account_ids = [var.management_account_id]

  default_tags {
    tags = {
      project             = "aws-landing-zone-lab"
      component           = "bootstrap"
      env                 = "management"
      owner               = "platform"
      data-classification = "internal"
      managed-by          = "terraform"
    }
  }
}
