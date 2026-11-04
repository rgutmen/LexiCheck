module "stack" {
  source    = "../../modules/stack"
  providers = { aws = aws, aws.us_east_1 = aws.us_east_1 }

  environment       = "staging"
  github_repository = var.github_repository
  vpc_cidr          = "10.20.0.0/16"
  alert_emails      = var.alert_emails
}
