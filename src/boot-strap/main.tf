### Start Creating S3 bucket to maitain tfstate ###
resource "aws_s3_bucket" "tfstatebucket" {
  bucket = "${var.aws-s3_bkt-terraform_state_backend}"
  acl    = "private"

  ## Force delete the bucket (delete all versions). Commented force_destroy on purpose
  # force_destroy = true

  versioning {
    enabled = true
  }
  ### Start Enable Server-Side encryption ###
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  ### End Server-Side encryption ###

  tags {
    Name = "${var.env}"
  }
}

### End Creating S3 bucket ###
### Start creating DynamoDB table ###
resource "aws_dynamodb_table" "tfstatedynamotable" {
  name           = "terraform-state-lock"
  hash_key       = "LockID"
  read_capacity  = 5
  write_capacity = 5

  attribute {
    name = "LockID"
    type = "S"
  }

  tags {
    Name = "${var.env}"
  }
}

### End Creating DynamoDB table ###

