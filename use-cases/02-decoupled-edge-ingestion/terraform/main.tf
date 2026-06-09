# =============================================================================
# Provider
# =============================================================================
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-use-cases"
      UseCase     = "02-decoupled-edge-ingestion"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


# =============================================================================
# SQS Queues (DLQ must be created first, main queue references it)
# =============================================================================
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_prefix}-dlq"
  message_retention_seconds = 1209600 # 14 days - max retention for inspection
}

resource "aws_sqs_queue" "telemetry" {
  name                       = "${var.project_prefix}-telemetry"
  visibility_timeout_seconds = 60    # Must be >= Lambda timeout
  message_retention_seconds  = 86400 # 1 day

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3 # After 3 failures, move to DLQ
  })
}


# =============================================================================
# DynamoDB Table
# =============================================================================
resource "aws_dynamodb_table" "telemetry" {
  name         = "${var.project_prefix}-telemetry"
  billing_mode = "PAY_PER_REQUEST" # On-demand, no capacity planning

  hash_key  = "device_id"
  range_key = "timestamp"

  attribute {
    name = "device_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }
}

# =============================================================================
# Lambda Function
# =============================================================================

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/lambda.zip"
}


resource "aws_iam_role" "lambda" {
  name = "${var.project_prefix}-lambda-role"
  assume_role_policy = jsonencode(({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  }))
}

resource "aws_iam_role_policy" "lambda" {
  name = "${var.project_prefix}-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # CloudWatch Logs
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        # SQS - receive and delete messages
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.telemetry.arn
      },
      {
        # DynamoDB - write items
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem"]
        Resource = aws_dynamodb_table.telemetry.arn
      }
    ]
  })
}


resource "aws_lambda_function" "processor" {
  function_name    = "${var.project_prefix}-processor"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda.arn
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.telemetry.name
    }
  }
}


# Lambda triggered by SQS
resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn = aws_sqs_queue.telemetry.arn
  function_name    = aws_lambda_function.processor.arn
  batch_size       = 10 # Process up to 10 messages per invocation
}


# =============================================================================
# IoT Rule (sends to SQS)
# =============================================================================
resource "aws_iam_role" "iot" {
  name = "${var.project_prefix}-iot-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "iot.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "iot" {
  name = "${var.project_prefix}-iot-policy"
  role = aws_iam_role.iot.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.telemetry.arn
    }]
  })
}


resource "aws_iot_topic_rule" "telemetry" {
  name        = "${replace(var.project_prefix, "-", "_")}_telemetry_rule"
  description = "Routes telemetry to SQS for buffered processing"
  enabled     = true
  sql         = "SELECT *, topic(2) AS device_id FROM 'sensors/+/telemetry'"
  sql_version = "2016-03-23"

  sqs {
    queue_url  = aws_sqs_queue.telemetry.url
    role_arn   = aws_iam_role.iot.arn
    use_base64 = false
  }
}