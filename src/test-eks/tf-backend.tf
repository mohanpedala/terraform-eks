### Start Changing Terraform Backend ###
## Check about terraform.backend: configuration cannot contain interpolations
terraform {
  backend "s3" {
    bucket = "prod-terraform-state-backend"
    key    = "terraform-state-lock"
    region = "us-west-2"

    # "${var.region}"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

### End Changing Terraform Backend ###

