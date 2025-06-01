resource "aws_ecr_repository" "app" {
  name = "${var.environment}-${var.app_name}"
}

resource "aws_ecs_cluster" "this" {
  name = "${var.environment}-cluster"
}

resource "aws_ecs_task_definition" "app" {
  family             = "${var.environment}-${var.app_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode       = "awsvpc"
  cpu                = "256"
  memory             = "512"
  execution_role_arn = var.ecs_task_execution_role_arn
  container_definitions = jsonencode([
    {
      name  = var.app_name
      image = "${aws_ecr_repository.app.repository_url}:latest"
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "DOMAIN"
          value = "production"
        },
        {
          name  = "POSTGRES_USER"
          value = "avnadmin"
        },
        {
          name  = "POSTGRES_SERVER"
          value = "db-veyra-veyra.c.aivencloud.com:22634"
        },
        {
          name  = "POSTGRES_DB"
          value = "defaultdb"
        },
        {
          name  = "OPEN_AI_EMBEDDING_MODEL_NAME"
          value = "text-embedding-3-small"
        },
        {
          name  = "PERPLEXITY_API_URL"
          value = "https://api.perplexity.ai/chat/completions"
        },
        {
          name  = "PINECONE_REGION"
          value = "us-east-1"
        },
        {
          name  = "PINECONE_REGION"
          value = "aws"
        }
      ],
      secrets = [
        {
          name      = "POSTGRES_PASSWORD"
          valueFrom = aws_secretsmanager_secret.postgres_password.arn
        },
        {
          name      = "OPEN_AI_API_KEY"
          valueFrom = aws_secretsmanager_secret.open_ai_api_key.arn
        },
        {
          name      = "OPEN_AI_ASSISTANT_ID"
          valueFrom = aws_secretsmanager_secret.open_ai_assistant_id.arn
        },
        {
          name      = "OPEN_AI_EMBEDDING_API_KEY"
          valueFrom = aws_secretsmanager_secret.open_ai_embedding_api_key.arn
        },
        {
          name      = "PERPLEXITY_API_KEY"
          valueFrom = aws_secretsmanager_secret.perplexity_api_key.arn
        },
        {
          name      = "PINECONE_API_KEY"
          valueFrom = aws_secretsmanager_secret.pinecone_api_key.arn
        }
      ],
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

# Secrets
resource "aws_secretsmanager_secret" "postgres_password" {
  name = "${var.environment}-postgres-password"
}

resource "aws_secretsmanager_secret" "open_ai_api_key" {
  name = "${var.environment}-open-ai-api-key"
}

resource "aws_secretsmanager_secret" "open_ai_assistant_id" {
  name = "${var.environment}-open-ai-assistant-id"
}

resource "aws_secretsmanager_secret" "open_ai_embedding_api_key" {
    name = "${var.environment}-open-ai-embedding-api-key"
}

resource "aws_secretsmanager_secret" "perplexity_api_key" {
  name = "${var.environment}-perplexity-api-key"
}

resource "aws_secretsmanager_secret" "pinecone_api_key" {
  name = "${var.environment}-pinecone-api-key"
}
