variable "region" {
  type        = string
  description = "The default region where project and resources should reside"
}
variable "environment" {
  type        = string
  description = "Environment name."
}
variable "app_name" {
  type        = string
  description = "Name of the application."
}
variable "domain" {
  type        = string
  description = "Domain name for the backend service."
}
variable "ecs_task_execution_role_arn" {
  type        = string
  description = "The ARN of the ECS task execution IAM role."
}
variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the ECS service."
}
variable "security_group_id" {
  type        = string
  description = "Security group ID for the ECS service."
}
variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where the ECS service is deployed."
}
variable "external_services" {
  type = object(
    {
      CHAT_AI_MODEL_PROVIDER = string
    }
  )
}
