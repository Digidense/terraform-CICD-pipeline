variable "region" {
  default = "us-east-1"
}

variable "api_gateway_name" {
  description = "api gateway name"
}

# variable "route53_zone_id" {
#   description = "Route53 hosted zone ID"
#   type        = string
# }
#
# variable "acm_certificate_arn" {
#   description = "acm_certificate_arn"
#   type        = string
# }