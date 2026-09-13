terraform {}

provider "aws" {
  region                      = var.aws_region
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
  s3_use_path_style           = true

  endpoints {
    cloudwatch = "http://127.0.0.1:4566"
    logs       = "http://127.0.0.1:4566"
    sns        = "http://127.0.0.1:4566"
    sqs        = "http://127.0.0.1:4566"
    ec2        = "http://127.0.0.1:4566"
    rds        = "http://127.0.0.1:4566"
    sts        = "http://127.0.0.1:4566"
    iam        = "http://127.0.0.1:4566"
    kms        = "http://127.0.0.1:4566"
  }
}



