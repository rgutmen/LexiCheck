variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "github_repository" {
  type = string
}

variable "alert_emails" {
  type    = list(string)
  default = []
}
