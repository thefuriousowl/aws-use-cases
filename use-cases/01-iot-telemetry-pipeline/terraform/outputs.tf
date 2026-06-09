output "timestream_database" {
  description = "Timestream database name"
  value       = aws_timestreamwrite_database.iot.database_name
}

output "timestream_table" {
  description = "Timestream table name"
  value       = aws_timestreamwrite_table.telemetry.table_name
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.processor.function_name
}

output "iot_topic" {
  description = "MQTT topic to publish to"
  value       = "sensors/{device_id}/telemetry"
}

output "iot_rule_name" {
  description = "IoT Rule name"
  value       = aws_iot_topic_rule.telemetry.name
}
