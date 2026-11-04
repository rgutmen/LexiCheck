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

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "deletion_protection" {
  type    = bool
  default = true
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "alb_arn_suffix" {
  value = aws_lb.this.arn_suffix
}

output "target_group_arn_suffix" {
  value = aws_lb_target_group.api.arn_suffix
}

output "origin_secret" {
  value     = random_password.origin_secret.result
  sensitive = true
}

output "task_security_group_id" {
  value = aws_security_group.task.id
}

output "ecr_repository_url" {
  value = aws_ecr_repository.api.repository_url
}

output "ecr_repository_arn" {
  value = aws_ecr_repository.api.arn
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.api.name
}

output "task_family" {
  value = aws_ecs_task_definition.api.family
}

output "role_arns" {
  value = [aws_iam_role.execution.arn, aws_iam_role.task.arn]
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.api.name
}
