module "budget" {
  source          = "../../modules/budget"
  name            = "lexicheck"
  monthly_limit   = var.monthly_budget
  warning_percent = 80
  emails          = var.budget_emails
}

module "ci_roles" {
  source                     = "../../modules/ci-roles"
  name                       = "lexicheck"
  github_repository          = var.github_repository
  github_oidc_subject_prefix = var.github_oidc_subject_prefix
  state_bucket               = var.state_bucket
}
