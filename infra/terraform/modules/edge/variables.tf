variable "name" {
  type = string
}

variable "api_origin_domain" {
  description = "DNS name of the ALB fronting the API"
  type        = string
}

variable "api_origin_https" {
  description = "Whether CloudFront reaches the ALB over HTTPS (needs a certificate on the ALB)"
  type        = bool
  default     = false
}

variable "origin_secret" {
  type      = string
  sensitive = true
}

variable "domain_names" {
  type    = list(string)
  default = []
}

variable "acm_certificate_arn" {
  description = "us-east-1 ACM certificate covering domain_names. Null uses *.cloudfront.net."
  type        = string
  default     = null
}

variable "price_class" {
  description = "PriceClass_All serves Asia/South America from local edges; PriceClass_100 is US/EU only."
  type        = string
  default     = "PriceClass_100"
}

variable "rate_limit_per_5min" {
  type    = number
  default = 2000
}

variable "deletion_protection" {
  type    = bool
  default = true
}
