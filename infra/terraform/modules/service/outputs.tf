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

output "openai_secret_id" {
  value = aws_secretsmanager_secret.openai.id
}
