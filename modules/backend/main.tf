resource "aws_ecr_repository" "app" {
  name = "${var.environment}-${var.app_name}"
}

resource "aws_ecs_cluster" "this" {
  name = "${var.environment}-cluster"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.environment}-${var.app_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = "256"
  memory                  = "512"
  execution_role_arn      = var.ecs_task_execution_role_arn

  container_definitions = jsonencode([
    {
      name      = var.app_name
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      portMappings = [{
        containerPort = 80
        hostPort      = 80
        protocol      = "tcp"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.environment}-${var.app_name}"
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = "${var.environment}-${var.app_name}"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.subnet_ids
    assign_public_ip = true
    security_groups = [var.security_group_id]
  }
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.environment}-${var.app_name}"
  retention_in_days = 7
}
