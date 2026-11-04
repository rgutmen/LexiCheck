variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "github_repository" {
  description = "owner/repo allowed to deploy via OIDC"
  type        = string
}

variable "vpc_cidr" {
  type = string
}

variable "task_cpu" {
  type    = number
  default = 256
}

variable "task_memory" {
  type    = number
  default = 512
}

variable "min_tasks" {
  type    = number
  default = 1
}

variable "max_tasks" {
  type    = number
  default = 4
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "alb_certificate_arn" {
  type    = string
  default = null
}

variable "cloudfront_certificate_arn" {
  type    = string
  default = null
}

variable "domain_names" {
  type    = list(string)
  default = []
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
