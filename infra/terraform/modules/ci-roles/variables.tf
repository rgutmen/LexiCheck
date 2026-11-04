variable "name" {
  type = string
}

variable "github_repository" {
  description = "owner/repo allowed to assume these roles"
  type        = string
}

variable "state_bucket" {
  description = "S3 bucket holding Terraform state"
  type        = string
}
