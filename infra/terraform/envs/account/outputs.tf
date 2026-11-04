output "budget" {
  value = module.budget.budget_name
}

output "ci" {
  value = {
    plan_role_arn  = module.ci_roles.plan_role_arn
    apply_role_arn = module.ci_roles.apply_role_arn
  }
}
