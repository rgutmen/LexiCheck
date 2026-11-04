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

# Everything CI needs is exported, so workflows read it from `terraform output`
# instead of hardcoding names.
output "deploy" {
  value = {
    role_arn           = aws_iam_role.deploy.arn
    ecr_repository_url = module.service.ecr_repository_url
    cluster            = module.service.cluster_name
    service            = module.service.service_name
    task_family        = module.service.task_family
    site_bucket        = module.edge.site_bucket
    distribution_id    = module.edge.distribution_id
  }
}

output "url" {
  value = "https://${coalesce(one(var.domain_names), module.edge.domain_name)}"
}
