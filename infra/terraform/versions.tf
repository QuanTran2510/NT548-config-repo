terraform {
  required_version = ">= 1.10" # native S3 state locking (use_lockfile) needs 1.10+
  required_providers {
    aws   = { source = "hashicorp/aws", version = "~> 5.0" }
    local = { source = "hashicorp/local", version = "~> 2.4" }
  }

  # State lives in S3 so the laptop AND GitHub Actions see the same infrastructure.
  # Bucket/key/region are passed at init time: see backend.hcl.example.
  backend "s3" {}
}

# No keys in code. Learner Lab credentials are temporary: export AWS_ACCESS_KEY_ID /
# AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN locally, or store them as GitHub secrets for CI.
provider "aws" {
  region = var.aws_region
}
