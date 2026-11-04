module "stack" {
  source    = "../../modules/stack"
  providers = { aws = aws, aws.us_east_1 = aws.us_east_1 }

  environment       = "prod"
  github_repository = var.github_repository
  vpc_cidr          = "10.30.0.0/16"
  alert_emails      = var.alert_emails
  task_cpu          = 512
  task_memory       = 1024
  min_tasks         = 3
  max_tasks         = 30
  db_instance_class = "db.r7g.large"
}
