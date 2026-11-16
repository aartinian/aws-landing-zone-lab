provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project             = "aws-landing-zone-lab"
      component           = "organization"
      env                 = "management"
      owner               = "platform"
      data-classification = "internal"
      managed-by          = "terraform"
    }
  }
}
