provider "aws" {
  region = "us-east-1"

  dynamic "endpoints" {
    for_each = var.floci_endpoint != "" ? [1] : []
    content {
      s3          = var.floci_endpoint
      ecr         = var.floci_endpoint
      ecs         = var.floci_endpoint
      lambda      = var.floci_endpoint
      iam         = var.floci_endpoint
      scheduler   = var.floci_endpoint
      cloudwatch  = var.floci_endpoint
      events      = var.floci_endpoint
      logs        = var.floci_endpoint
    }
  }

  skip_credentials_validation = var.floci_endpoint != ""
  skip_requesting_account_id  = var.floci_endpoint != ""
  skip_metadata_api_check     = var.floci_endpoint != ""
  s3_use_path_style           = var.floci_endpoint != ""
}
