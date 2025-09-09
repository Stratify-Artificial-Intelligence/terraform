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
variable "default_instances_count" {
  type        = number
  description = "Minimum number of instances for the ECS service."
  default     = 1
}
variable "external_services" {
  type = object(
    {
      CHAT_AI_MODEL_PROVIDER = string
    }
  )
}
variable "step_function_research_handler_arn" {
  type        = string
  description = "The ARN of the Step Function Research Handler."
  default     = null
}
variable "step_function_user_access_key_id_arn" {
  type        = string
  description = "The ARN of the Secrets Manager secret holding the access key ID for the Step Function user."
  default     = null
}
variable "step_function_user_secret_access_key_arn" {
  type        = string
  description = "The ARN of the Secrets Manager secret holding the secret access key for the Step Function user."
  default     = null
}
variable "eventbridge_scheduler_role_arn" {
  type        = string
  description = "The ARN of the EventBridge Scheduler role."
  default     = null
}
variable "eventbridge_user_access_key_id_arn" {
  type        = string
  description = "The ARN of the Secrets Manager secret holding the access key ID for the Event Bridge user."
  default     = null
}
variable "eventbridge_user_secret_access_key_arn" {
  type        = string
  description = "The ARN of the Secrets Manager secret holding the secret access key for the Event Bridge user."
  default     = null
}
variable "eventbridge_lambda_function_arn" {
  type        = string
  description = "The ARN of the Lambda function that EventBridge Scheduler will invoke."
  default     = null
}
