provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "lexicheck", Environment = "account", ManagedBy = "terraform" }
  }
}
