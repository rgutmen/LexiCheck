terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
  }

  # Account-level resources live in their own state, so tearing down an
  # environment never removes the cost alerts.
  backend "s3" {
    key          = "lexicheck/account/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "lexicheck", Environment = "account", ManagedBy = "terraform" }
  }
}
