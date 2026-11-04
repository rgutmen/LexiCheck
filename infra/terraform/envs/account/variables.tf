variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "monthly_budget" {
  description = "Monthly limit in USD for the whole account"
  type        = number
  default     = 20
}

variable "budget_emails" {
  type = list(string)
}

variable "github_repository" {
  description = "owner/repo whose workflows may run Terraform"
  type        = string
}

variable "state_bucket" {
  type = string
}

variable "github_oidc_subject_prefix" {
  description = "GitHub's immutable OIDC subject prefix, e.g. repo:owner@123/name@456. Null if the repo uses the classic repo:owner/name form."
  type        = string
  default     = null
}
