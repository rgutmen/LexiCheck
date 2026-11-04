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
