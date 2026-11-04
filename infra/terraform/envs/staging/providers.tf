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
