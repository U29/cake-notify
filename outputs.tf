output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.cake_notify_users.name
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.cake_notify.function_name
}

output "eventbridge_rule_name" {
  description = "EventBridge rule name"
  value       = aws_cloudwatch_event_rule.daily_notification.name
}
