terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  # Configure S3 Remote state
  backend "s3" {
    # bucket provided via -backend-config
    key          = "use-cases/02-decoupled-edge-ingestion/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }
}