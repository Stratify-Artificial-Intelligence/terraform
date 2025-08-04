resource "aws_iam_role" "step_function_role" {
  name = "StepFunctionExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "states.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "step_function_policy" {
  name = "StepFunctionPolicy"
  role = aws_iam_role.step_function_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "states:StartExecution",
          "states:DescribeExecution",
          "states:StopExecution"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "states:InvokeHTTPEndpoint"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "events:RetrieveConnectionCredentials"
        ],
        Effect   = "Allow",
        Resource = aws_cloudwatch_event_connection.step_function_api_connection.arn
      },
      {
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:DescribeLogGroups",
          "logs:DescribeResourcePolicies",
          "logs:PutResourcePolicy",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "step_function_log_group" {
  name              = "/aws/vendedlogs/states/${var.environment}-research-status-machine"
  retention_in_days = 7
}

# ToDo (pduran): [S-249] Remove this secret and use the IAM role instead
data "aws_secretsmanager_secret_version" "service_user_token" {
  secret_id = var.service_user_token_arn
}

resource "aws_cloudwatch_event_connection" "step_function_api_connection" {
  name               = "${var.environment}-step-function-api-connection"
  authorization_type = "API_KEY"

  auth_parameters {
    api_key {
      key   = "Authorization"
      value = "Bearer ${data.aws_secretsmanager_secret_version.service_user_token.secret_string}"
    }
  }
}

resource "aws_sfn_state_machine" "research_status_machine" {
  name     = "${var.environment}-research-status-machine"
  role_arn = aws_iam_role.step_function_role.arn
  type     = "STANDARD"

  definition = jsonencode({
    StartAt = "CheckResearchStatus",
    States = {
      CheckResearchStatus = {
        Type     = "Task",
        Resource = "arn:aws:states:::http:invoke",
        Parameters = {
          "ApiEndpoint.$" = "States.Format('https://${var.domain}/researches/{}', $.research_id)"
          "Method"        = "GET",
          "Authentication" = {
            "ConnectionArn" = aws_cloudwatch_event_connection.step_function_api_connection.arn
          }
        },
        ResultSelector = {
          "status.$" : "$.ResponseBody.status"
        },
        ResultPath = "$.status",
        Next = "EvaluateStatus"
      },
      EvaluateStatus = {
        Type = "Choice",
        Choices = [
          {
            Variable     = "$.status.status",
            StringEquals = "COMPLETED",
            Next         = "StoreResearch"
          },
          {
            Variable     = "$.status.status",
            StringEquals = "FAILED",
            Next         = "FailState"
          },
          {
            Or = [
              { Variable = "$.status.status", StringEquals = "IN_PROGRESS" },
              { Variable = "$.status.status", StringEquals = "CREATED" }
            ],
            Next = "WaitBeforeRetry"
          }
        ],
        Default = "FailState"
      },
      WaitBeforeRetry = {
        Type    = "Wait",
        Seconds = 30,
        Next    = "CheckResearchStatus"
      },
      StoreResearch = {
        Type     = "Task",
        Resource = "arn:aws:states:::http:invoke",
        Parameters = {
          "ApiEndpoint" = "https://${var.domain}/researches/store"
          "Method"      = "POST",
          "Authentication" = {
            "ConnectionArn" = aws_cloudwatch_event_connection.step_function_api_connection.arn
          },
          "RequestBody" = {
            "research_id.$" = "$.research_id"
            "business_id.$" = "$.business_id"
          }
        },
        End = true
      },
      FailState = {
        Type  = "Fail",
        Error = "ResearchFailed",
        Cause = "Research returned FAILED or unknown status"
      }
    }
  })
}


# User so that backend can access the step function
# ToDo (pduran): If more step functions were to be defined, this user should be common
#  for all of them, or a more generic role should be created.
resource "aws_iam_user" "step_function_executor" {
  name = "${var.environment}-step-function-executor"
}

data "aws_iam_policy_document" "step_function_policy_document" {
  statement {
    actions = ["states:StartExecution"]
    # ToDo (pduran): If more step functions were to be defined, this should be expanded.
    resources = [aws_sfn_state_machine.research_status_machine.arn]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "step_function_policy" {
  name        = "StepFunctionExecutionPolicy"
  policy      = data.aws_iam_policy_document.step_function_policy_document.json
  description = "Allows a user to start Step Function execution."
}

resource "aws_iam_user_policy_attachment" "step_function_attachment" {
  user       = aws_iam_user.step_function_executor.name
  policy_arn = aws_iam_policy.step_function_policy.arn
}

resource "aws_iam_access_key" "step_function_key" {
  user = aws_iam_user.step_function_executor.name
}

resource "aws_secretsmanager_secret" "aws_access_key_id" {
  name        = "${var.environment}-aws-step-function-access-key-id"
  description = "Access Key ID for the Step Functions user."
}

resource "aws_secretsmanager_secret_version" "aws_access_key_version" {
  secret_id     = aws_secretsmanager_secret.aws_access_key_id.id
  secret_string = aws_iam_access_key.step_function_key.id
}

resource "aws_secretsmanager_secret" "aws_secret_access_key" {
  name        = "${var.environment}-aws-step-function-secret-access-key-id"
  description = "Secret Access Key for the Step Functions user."
}

resource "aws_secretsmanager_secret_version" "aws_secret_access_key_version" {
  secret_id     = aws_secretsmanager_secret.aws_secret_access_key.id
  secret_string = aws_iam_access_key.step_function_key.secret
}
