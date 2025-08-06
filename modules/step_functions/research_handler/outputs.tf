output "arn" {
  value = aws_sfn_state_machine.research_status_machine.arn
}

output "step_function_user_access_key_id_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the access key ID."
  value       = aws_secretsmanager_secret.aws_access_key_id.arn
}

output "step_function_user_secret_access_key_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the secret access key."
  value       = aws_secretsmanager_secret.aws_secret_access_key.arn
}
