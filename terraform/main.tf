# Provider + backend.
#
# State lives in S3 with native lockfile locking (no DynamoDB table). The bucket
# is created once by hand (docs/aws-runbook.md, step 2) and passed at init time:
#   terraform init -backend-config=backend.hcl
# Offline (validate/test) use: terraform init -backend=false

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.67"
    }
  }

  backend "s3" {
    key          = "devsecops-pipeline/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  # Every resource gets these tags, so cost and cleanup can be filtered by project.
  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project   = var.project
    ManagedBy = "terraform"
    Repo      = var.github_repo
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
