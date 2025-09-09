resource "aws_iam_role" "eventbridge_role" {
  name = "${var.environment}-eventbridge-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "eventbridge_rule_policy" {
  name = "${var.environment}-eventbridge-execution-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "scheduler:CreateSchedule",
        Effect = "Allow",
        # ToDo (pduran): Restrict this to specific schedules
        Resource = "*"
      },
      {
        Action   = "iam:PassRole",
        Effect   = "Allow",
        Resource = aws_iam_role.eventbridge_role.arn
      },
      {
        Action = "lambda:InvokeFunction",
        Effect = "Allow",
        # ToDo (pduran): Restrict this to specific lambdas
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eventbridge_rule_attachment" {
  role       = aws_iam_role.eventbridge_role.name
  policy_arn = aws_iam_policy.eventbridge_rule_policy.arn
}

resource "aws_iam_user" "eventbridge_executor" {
  name = "${var.environment}-eventbridge-executor"
}

resource "aws_iam_user_policy_attachment" "eventbridge_attachment" {
  user       = aws_iam_user.eventbridge_executor.name
  policy_arn = aws_iam_policy.eventbridge_rule_policy.arn
}

resource "aws_iam_access_key" "eventbridge_key" {
  user = aws_iam_user.eventbridge_executor.name
}

resource "aws_secretsmanager_secret" "aws_access_key_id" {
  name        = "${var.environment}-aws-eventbridge-business-research-access-key-id"
  description = "Access Key ID for the Event Bridge user."
}

resource "aws_secretsmanager_secret_version" "aws_access_key_version" {
  secret_id     = aws_secretsmanager_secret.aws_access_key_id.id
  secret_string = aws_iam_access_key.eventbridge_key.id
}

resource "aws_secretsmanager_secret" "aws_secret_access_key" {
  name        = "${var.environment}-aws-eventbridge-business-research-secret-access-key-id"
  description = "Secret Access Key for the Event Bridge user."
}

resource "aws_secretsmanager_secret_version" "aws_secret_access_key_version" {
  secret_id     = aws_secretsmanager_secret.aws_secret_access_key.id
  secret_string = aws_iam_access_key.eventbridge_key.secret
}


# Lambda function that is invoked
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.environment}-business-research-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 3. Custom policy to allow reading the specific secret from Secrets Manager
resource "aws_iam_policy" "get_secret_policy" {
  name   = "${var.environment}-business-research-lambda-role-get-secret-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "secretsmanager:GetSecretValue",
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_secret_access" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.get_secret_policy.arn
}

# This data resource creates a dummy empty zip file to use as a placeholder.
# AWS requires some code to be present upon creation, even if you update it manually later.
data "archive_file" "dummy_zip" {
  type        = "zip"
  output_path = "${path.module}/dummy.zip"

  source {
    content  = "exports.handler = async (event) => { console.log('This is placeholder code.'); };"
    filename = "index.js"
  }
}

# ToDo (pduran): [S-249] Remove this secret and use the IAM role instead
data "aws_secretsmanager_secret_version" "service_user_token" {
  secret_id = var.service_user_token_arn
}

# The Lambda Function resource
resource "aws_lambda_function" "business_research_lambda" {
  function_name = "${var.environment}-business-research-lambda"
  role          = aws_iam_role.lambda_execution_role.arn

  # Standard Lambda settings
  handler = "lambda_function.lambda_handler"
  runtime = "python3.10"

  # Using the dummy zip file as a placeholder for the code
  filename         = data.archive_file.dummy_zip.output_path
  source_code_hash = data.archive_file.dummy_zip.output_base64sha256

  environment {
    variables = {
      BACKEND_DOMAIN = "https://${var.domain}"
      SERVICE_TOKEN = data.aws_secretsmanager_secret_version.service_user_token.secret_string
    }
  }
  tags = {
    ManagedBy = "Terraform"
  }
}
