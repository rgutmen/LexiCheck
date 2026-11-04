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

variable "github_oidc_subject_prefix" {
  description = "GitHub's immutable OIDC subject prefix, e.g. repo:owner@123/name@456. Null if the repo uses the classic repo:owner/name form."
  type        = string
  default     = null
}
