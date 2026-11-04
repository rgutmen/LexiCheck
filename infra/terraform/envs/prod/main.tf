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
    key          = "lexicheck/prod/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "lexicheck", Environment = "prod", ManagedBy = "terraform" }
  }
}

# CloudFront WAF and certificates must live in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags {
    tags = { Project = "lexicheck", Environment = "prod", ManagedBy = "terraform" }
  }
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "github_repository" {
  type = string
}

variable "alert_emails" {
  type    = list(string)
  default = []
}

module "stack" {
  source    = "../../modules/stack"
  providers = { aws = aws, aws.us_east_1 = aws.us_east_1 }

  environment       = "prod"
  github_repository = var.github_repository
  vpc_cidr          = "10.30.0.0/16"
  alert_emails      = var.alert_emails
  task_cpu          = 512
  task_memory       = 1024
  min_tasks         = 3
  max_tasks         = 30
  db_instance_class = "db.r7g.large"
}

output "deploy" {
  value = module.stack.deploy
}

output "url" {
  value = module.stack.url
}
