output "sqs_queue_url" {
  description = "URL of the main SQS queue"
  value       = aws_sqs_queue.telemetry.url
}

output "sqs_dlq_url" {
  description = "URL of the dead letter queue"
  value       = aws_sqs_queue.dlq.url
}


output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.telemetry.name
}


output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.processor.function_name
}

output "iot_topic" {
  description = "MQTT topic pattern for publishing"
  value       = "sensors/{device_id}/telemetry"
}


output "iot_rule_name" {
  description = "Name of the IoT Rule"
  value       = aws_iot_topic_rule.telemetry.name
}