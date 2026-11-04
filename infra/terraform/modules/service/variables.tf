variable "name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "app_subnet_ids" {
  type = list(string)
}

variable "certificate_arn" {
  description = "Regional ACM certificate for the ALB. Null serves plain HTTP behind CloudFront."
  type        = string
  default     = null
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "image_tag" {
  description = "Initial image tag. Later deploys are driven by CI, not Terraform."
  type        = string
  default     = "bootstrap"
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "min_tasks" {
  type    = number
  default = 2
}

variable "max_tasks" {
  type    = number
  default = 10
}

variable "requests_per_task_target" {
  type    = number
  default = 500
}

variable "spot_weight" {
  description = "Relative weight of FARGATE_SPOT above the on-demand base. 0 disables Spot."
  type        = number
  default     = 0
}

variable "db_host" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_secret_arn" {
  type = string
}

variable "db_kms_key_arn" {
  type = string
}

variable "cors_origins" {
  type    = list(string)
  default = []
}

variable "openai_model" {
  description = "Model used by the AI rewrite feature"
  type        = string
  default     = "gpt-4o-mini"
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "deletion_protection" {
  type    = bool
  default = true
}
