variable "environment" {
  type        = string
  description = "Environment name."
}
variable "app_name" {
  type        = string
  description = "Name of the application."
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
