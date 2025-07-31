terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

################################################################################
# Data Source
################################################################################

data "aws_caller_identity" "current" {}

################################################################################
# IAM Role and Policies for Lambda
################################################################################

# Lambda Execution Role
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Custom Policy for Accessing Bedrock
resource "aws_iam_policy" "lambda_bedrock_policy" {
  name        = "${var.project_name}-lambda-bedrock-policy"
  description = "IAM policy for Lambda to access Bedrock"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

# Attach Bedrock Policy to Lambda Role
resource "aws_iam_role_policy_attachment" "lambda_bedrock_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_bedrock_policy.arn
}

# Attach AWS Managed Lambda Basic Execution Role
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

################################################################################
# Lambda Deployment Package
################################################################################

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/lambda_function.zip"
  excludes    = ["test_payload.json"]
}

################################################################################
# Logging
################################################################################

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-bedrock-lambda"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

################################################################################
# Lambda Function
################################################################################

resource "aws_lambda_function" "bedrock_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-bedrock-lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "python3.11"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  environment {
    variables = {
      LOG_LEVEL = var.log_level
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_bedrock_policy_attachment,
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = var.tags
}

################################################################################
# Lambda Function URL (Direct Invocation)
################################################################################

resource "aws_lambda_function_url" "bedrock_lambda_url" {
  function_name      = aws_lambda_function.bedrock_lambda.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["POST"]
    allow_headers     = ["date", "keep-alive", "content-type"]
    expose_headers    = ["date", "keep-alive"]
    max_age           = 86400
  }
}
