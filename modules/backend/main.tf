resource "aws_ecr_repository" "app" {
  name = "${var.environment}-${var.app_name}"
}

resource "aws_ecs_cluster" "this" {
  name = "${var.environment}-cluster"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${var.environment}-${var.app_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.ecs_task_execution_role_arn
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
  depends_on      = [aws_lb_listener.app_listener]

  network_configuration {
    subnets          = var.subnet_ids
    assign_public_ip = true
    security_groups  = [var.security_group_id]
  }

  load_balancer {
    container_name   = var.app_name
    container_port   = 80
    target_group_arn = aws_lb_target_group.app_tg_2.arn
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

# Load balancer
resource "aws_lb" "app_alb" {
  name               = "${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = [var.security_group_id]
}

resource "aws_lb_target_group" "app_tg_2" {
  name        = "${var.environment}-app-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/tests/dummy"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg_2.arn
  }
#   default_action {
#     type = "redirect"
#     redirect {
#       port        = "443"
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
}

# resource "aws_lb_listener" "app_listener" {
#   load_balancer_arn = aws_lb.app_alb.arn
#   port              = 80
#   protocol          = "HTTP"
#
#   default_action {
#     type = "redirect"
#     redirect {
#       port        = "443"
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
# }

data "aws_route53_zone" "veyrai_domain" {
  name         = "veyrai.com"
  private_zone = false
}

resource "aws_route53_record" "backend" {
  zone_id = data.aws_route53_zone.veyrai_domain.zone_id
  name    = "backend.veyrai.com"
  type    = "A"

  alias {
    name                   = aws_lb.app_alb.dns_name
    zone_id                = aws_lb.app_alb.zone_id
    evaluate_target_health = true
  }
}

# ToDo (pduran): Configure HTTPS listener with ACM certificate
# resource "aws_route53_record" "cert_validation" {
#   for_each = {
#     for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       type   = dvo.resource_record_type
#       record = dvo.resource_record_value
#     }
#   }
#   zone_id = data.aws_route53_zone.veyrai_domain.zone_id
#   name    = each.value.name
#   type    = each.value.type
#   records = [each.value.record]
#   ttl     = 60
#   depends_on = [aws_acm_certificate.cert]
# }
#
# resource "aws_acm_certificate_validation" "cert_validation" {
#   certificate_arn         = aws_acm_certificate.cert.arn
#   validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
# }
#
# resource "aws_acm_certificate" "cert" {
#   domain_name       = "backend.veyrai.com"
#   validation_method = "DNS"
#   tags = {
#     Environment = var.environment
#   }
# }
#
# resource "aws_lb_listener" "https_listener" {
#   load_balancer_arn = aws_lb.app_alb.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   certificate_arn   = aws_acm_certificate_validation.cert_validation.certificate_arn
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app_tg_2.arn
#   }
# }
