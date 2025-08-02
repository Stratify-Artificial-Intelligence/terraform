variable "environment" {
  type        = string
  description = "Environment name."
}
variable "domain" {
  type        = string
  description = "Domain name for the backend service."
}
variable "service_user_token_arn" {
  type        = string
  description = "The ARN of the service user token for the backend service."
  default     = null
}
