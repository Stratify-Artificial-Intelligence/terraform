variable "region" {
  type        = string
  description = "The default region where project and resources should reside"
  default     = "eu-west-1"
}

variable "backend_domain" {
    type        = string
    description = "Domain name for the backend service"
    default     = "dev-backend.veyrai.com"
}
