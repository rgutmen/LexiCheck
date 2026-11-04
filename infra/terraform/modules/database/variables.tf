variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "client_security_group_id" {
  description = "Security group allowed to connect (the ECS service)"
  type        = string
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "max_storage_gb" {
  type    = number
  default = 100
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "performance_insights" {
  description = "Enable Performance Insights (off for short-lived test environments)"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  type    = bool
  default = true
}
