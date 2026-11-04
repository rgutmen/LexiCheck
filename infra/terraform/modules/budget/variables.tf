variable "name" {
  type = string
}

variable "monthly_limit" {
  description = "Monthly cost limit in USD"
  type        = number
  default     = 20
}

variable "warning_percent" {
  description = "Send an early warning when actual or forecasted spend passes this percentage"
  type        = number
  default     = 80
}

variable "emails" {
  description = "Who gets the budget emails"
  type        = list(string)
  validation {
    condition     = length(var.emails) > 0
    error_message = "Add at least one email address for budget alerts."
  }
}
