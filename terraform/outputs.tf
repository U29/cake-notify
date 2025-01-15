output "dynamodb_table_name" {
  value = aws_dynamodb_table.birthdays.name
}

output "lambda_function_name" {
  value = aws_lambda_function.notify_birthday.function_name
}

output "event_rule_name" {
  value = aws_cloudwatch_event_rule.daily_9am.name
}
