terraform {
  required_version = ">= 1.10"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.60" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }

  # Partial config: bucket and region come from backend.hcl (see README).
  # One state object per environment, encrypted at rest, locked with S3 native
  # conditional writes (use_lockfile), so no DynamoDB table is needed.
  backend "s3" {
    key          = "lexicheck/staging/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "lexicheck", Environment = "staging", ManagedBy = "terraform" }
  }
}

# CloudFront WAF and certificates must live in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags {
    tags = { Project = "lexicheck", Environment = "staging", ManagedBy = "terraform" }
  }
}
