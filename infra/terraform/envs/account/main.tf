module "budget" {
  source          = "../../modules/budget"
  name            = "lexicheck"
  monthly_limit   = var.monthly_budget
  warning_percent = 80
  emails          = var.budget_emails
}
