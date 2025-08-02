# ToDo (pduran): [S-249] Remove this secret and use the IAM role instead
output "service_user_token_arn" {
  description = "The ARN of the service user token for the backend service."
  value       = aws_secretsmanager_secret.service_user_token.arn
}