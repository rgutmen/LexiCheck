module "stack" {
  source    = "../../modules/stack"
  providers = { aws = aws, aws.us_east_1 = aws.us_east_1 }

  environment                = "dev"
  github_repository          = var.github_repository
  github_oidc_subject_prefix = var.github_oidc_subject_prefix
  vpc_cidr                   = "10.10.0.0/16"
  alert_emails               = var.alert_emails
}
