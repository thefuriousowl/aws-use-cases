provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-use-cases"
      UseCase     = "01-iot-telemetry-pipeline"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}


# =============================================================================
# TIMESTREAM
# =============================================================================

resource "aws_timestreamwrite_database" "iot" {
  database_name = "${var.project_prefix}-db"
}

resource "aws_timestreamwrite_table" "telemetry" {
  database_name = aws_timestreamwrite_database.iot.database_name
  table_name    = "telemetry"

  retention_properties {
    # Keep data in fast memory store for 24 hours (for recent queries)
    memory_store_retention_period_in_hours = 24
    # Keep data in magnetic store for 7 days (cheaper, for historical queries)
    magnetic_store_retention_period_in_days = 7
  }
}


# =============================================================================
# LAMBDA
# =============================================================================

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# IAM role that Lambda assumes
resource "aws_iam_role" "lambda" {
  name = "${var.project_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM policy for Lambda to write to Timestream and CloudWatch Logs
resource "aws_iam_role_policy" "lambda" {
  name = "${var.project_prefix}-lambda-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # CloudWatch Logs - for Lambda logging
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        # Timestream - write records
        Effect = "Allow"
        Action = [
          "timestream:WriteRecords",
          "timestream:DescribeEndpoints"
        ]
        Resource = aws_timestreamwrite_table.telemetry.arn
      },
      {
        # Timestream DescribeEndpoints needs wildcard (API requirement)
        Effect   = "Allow"
        Action   = "timestream:DescribeEndpoints"
        Resource = "*"
        # Justification: DescribeEndpoints is a global action, cannot be scoped to a resource
      }
    ]
  })
}

# Package Lambda code
data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/lambda.zip"
}

# Lambda function
resource "aws_lambda_function" "processor" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "${var.project_prefix}-processor"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "python3.12"
  timeout          = 30

  environment {
    variables = {
      TIMESTREAM_DATABASE = aws_timestreamwrite_database.iot.database_name
      TIMESTREAM_TABLE    = aws_timestreamwrite_table.telemetry.table_name
    }
  }
}


# =============================================================================
# IOT CORE
# =============================================================================

# IoT Topic Rule - listens for MQTT messages and invokes Lambda
resource "aws_iot_topic_rule" "telemetry" {
  name        = "${replace(var.project_prefix, "-", "_")}_telemetry_rule"
  description = "Routes telemetry messages from sensors to Lambda"
  enabled     = true
  sql         = "SELECT *, topic(2) as device_id FROM 'sensors/+/telemetry'"
  sql_version = "2016-03-23"

  lambda {
    function_arn = aws_lambda_function.processor.arn
  }
}

# Permission for IoT to invoke Lambda
resource "aws_lambda_permission" "iot" {
  statement_id  = "AllowIoTInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "iot.amazonaws.com"
  source_arn    = aws_iot_topic_rule.telemetry.arn
}
