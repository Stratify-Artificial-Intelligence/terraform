output "ecs_task_execution_role_arn" {
  description = "The ARN of the ECS task execution IAM role."
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "app_security_group_id" {
  description = "Security group ID for ECS inbound and outbound access."
  value       = aws_security_group.app_sg.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "vpc_id" {
  description = "The ID of the VPC where the ECS service is deployed."
  value       = aws_vpc.main.id
}
