output "eventbridge_scheduler_role_arn" {
  description = "IAM Role ARN that EventBridge Scheduler"
  value       = aws_iam_role.eventbridge_role.arn
}


output "eventbridge_user_access_key_id_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the access key ID."
  value       = aws_secretsmanager_secret.aws_access_key_id.arn
}

output "eventbridge_user_secret_access_key_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the secret access key."
  value       = aws_secretsmanager_secret.aws_secret_access_key.arn
}

output "eventbridge_lambda_function_arn" {
    description = "ARN of the Lambda function that EventBridge Scheduler will invoke."
    value       = aws_lambda_function.business_research_lambda.arn
}
