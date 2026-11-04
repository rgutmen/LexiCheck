terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers {
    aws    = { source = "hashicorp/aws", version = ">= 5.60, < 6.0" }
    random = { source = "hashicorp/random", version = ">= 3.6, < 4.0" }
  }

  # Partial config: bucket and region come from backend.hcl (see README).
  # One state object per environment, encrypted at rest, locked with S3 native
  # conditional writes (use_lockfile), so no DynamoDB table is needed.
  backend "s3" {
    key          = "lexicheck/dev/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
