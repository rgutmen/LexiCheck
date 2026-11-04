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
    region             = data.aws_region.current.name
    url                = "https://${coalesce(one(var.domain_names), module.edge.domain_name)}"
  }
}

output "url" {
  value = "https://${coalesce(one(var.domain_names), module.edge.domain_name)}"
}
