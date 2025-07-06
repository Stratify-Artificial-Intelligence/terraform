# =============================================================
# ================ ECR and ECS Infrastructure =================
# =============================================================
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
  task_role_arn            = var.ecs_task_execution_role_arn
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
          value = var.environment
        },
        {
          name  = "POSTGRES_USER"
          value = aws_db_instance.postgres.username
        },
        {
          name  = "POSTGRES_SERVER"
          value = "${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}"
        },
        {
          name  = "POSTGRES_DB"
          value = aws_db_instance.postgres.db_name
        },
        {
          name  = "STORAGE_BUCKET_NAME"
          value = aws_s3_bucket.app_bucket.bucket
        },
        {
          name  = "STORAGE_REGION"
          value = var.region
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
          # valueFrom = aws_db_instance.postgres.password
        },
        {
          name      = "FIREBASE_AUTH_PRIVATE_KEY"
          valueFrom = aws_secretsmanager_secret.firebase_auth_private_key.arn
        },
        {
          name      = "FIREBASE_AUTH_API_KEY"
          valueFrom = aws_secretsmanager_secret.firebase_auth_api_key.arn
        },
        {
          name      = "STORAGE_ACCESS_KEY_ID"
          valueFrom = aws_secretsmanager_secret.aws_access_key_id.arn
        },
        {
          name      = "STORAGE_SECRET_ACCESS_KEY"
          valueFrom = aws_secretsmanager_secret.aws_secret_access_key.arn
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
          name      = "ANTHROPIC_API_KEY"
          valueFrom = aws_secretsmanager_secret.anthropic_api_key.arn
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
        },
        {
          name      = "STRIPE_API_KEY"
          valueFrom = aws_secretsmanager_secret.stripe_api_key.arn
        },
        {
          name      = "STRIPE_WEBHOOK_SECRET"
          valueFrom = aws_secretsmanager_secret.stripe_webhook_secret.arn
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
  desired_count   = 2
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

# Scaling Configuration
resource "aws_appautoscaling_target" "ecs_app" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_app_cpu_policy" {
  name               = "${var.environment}-${var.app_name}-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_app.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_app.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_app.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 60.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}


# =============================================================
# =================== Secrets Management ======================
# =============================================================
resource "aws_secretsmanager_secret" "postgres_password" {
  name = "${var.environment}-postgres-password"
}

resource "aws_secretsmanager_secret" "firebase_auth_private_key" {
  name = "${var.environment}-firebase-auth-private-key"
}

resource "aws_secretsmanager_secret" "firebase_auth_api_key" {
  name = "${var.environment}-firebase-auth-api-key"
}

resource "aws_secretsmanager_secret" "open_ai_api_key" {
  name = "${var.environment}-open-ai-api-key"
}

resource "aws_secretsmanager_secret" "open_ai_assistant_id" {
  name = "${var.environment}-open-ai-assistant-id"
}

resource "aws_secretsmanager_secret" "anthropic_api_key" {
  name = "${var.environment}-anthropic-api-key"
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

resource "aws_secretsmanager_secret" "stripe_api_key" {
  name = "${var.environment}-stripe-api-key"
}

resource "aws_secretsmanager_secret" "stripe_webhook_secret" {
  name = "${var.environment}-stripe-webhook-secret"
}

resource "aws_secretsmanager_secret" "aws_access_key_id" {
  name = "${var.environment}-aws-access-key-id"
}

resource "aws_secretsmanager_secret_version" "aws_access_key_version" {
  secret_id     = aws_secretsmanager_secret.aws_access_key_id.id
  secret_string = aws_iam_access_key.backend_user_key.id
}

resource "aws_secretsmanager_secret" "aws_secret_access_key" {
  name = "${var.environment}-aws-secret-access-key"
}

resource "aws_secretsmanager_secret_version" "aws_secret_access_key_version" {
  secret_id     = aws_secretsmanager_secret.aws_secret_access_key.id
  secret_string = aws_iam_access_key.backend_user_key.secret
}

# =============================================================
# ================== S3 Bucket for Storage ====================
# =============================================================
resource "aws_s3_bucket" "app_bucket" {
  bucket        = "${var.environment}-${var.app_name}-bucket-veyrai"
  force_destroy = true

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-${var.app_name}-bucket"
  }
}

resource "aws_s3_bucket_ownership_controls" "app_bucket_acl" {
  bucket = aws_s3_bucket.app_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.app_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "arn:aws:s3:::${aws_s3_bucket.app_bucket.bucket}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_public_access_block" "app_bucket_block" {
  bucket = aws_s3_bucket.app_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_iam_user" "app_storage_user" {
  name = "${var.environment}-backend-user"
}

resource "aws_iam_user_policy_attachment" "backend_s3_access" {
  user       = aws_iam_user.app_storage_user.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_access_key" "backend_user_key" {
  user = aws_iam_user.app_storage_user.name
}

# =============================================================
# ============= Load Balancer and ACM Certificate =============
# =============================================================
resource "aws_lb" "app_alb" {
  name               = "${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = [var.security_group_id]
  idle_timeout       = 900
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
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

data "aws_route53_zone" "veyrai_domain" {
  name         = "veyrai.com"
  private_zone = false
}

resource "aws_route53_record" "backend" {
  zone_id = data.aws_route53_zone.veyrai_domain.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = aws_lb.app_alb.dns_name
    zone_id                = aws_lb.app_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }
  zone_id    = data.aws_route53_zone.veyrai_domain.zone_id
  name       = each.value.name
  type       = each.value.type
  records    = [each.value.record]
  ttl        = 60
  depends_on = [aws_acm_certificate.cert]
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain
  validation_method = "DNS"
  tags = {
    Environment = var.environment
  }
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.cert_validation.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg_2.arn
  }
}

# =============================================================
# ================== RDS PostgreSQL Instance ==================
# =============================================================
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.environment}-rds-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.environment}-rds-subnet-group"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.environment}-rds-sg"
  description = "Allow PostgreSQL from ECS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "${var.environment}-postgres-db"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15.12"
  instance_class         = "db.t3.micro"
  username               = "admindb"
  db_name                = "defaultdb"
  password               = aws_secretsmanager_secret.postgres_password.arn
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  skip_final_snapshot    = true
  publicly_accessible    = true

  tags = {
    Name = "${var.environment}-postgres-db"
  }
}
