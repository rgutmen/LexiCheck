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

variable "github_oidc_subject_prefix" {
  description = "GitHub's immutable OIDC subject prefix, e.g. repo:owner@123/name@456. Null if the repo uses the classic repo:owner/name form."
  type        = string
  default     = null
}
