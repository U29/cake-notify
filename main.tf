provider "aws" {
  region = "ap-northeast-1"
  
  endpoints {
    dynamodb = var.dynamodb_endpoint
    lambda = var.lambda_endpoint
    events = var.events_endpoint
    iam = var.iam_endpoint
  }
}

resource "aws_dynamodb_table" "cake_notify_users" {
  name = "cake_notify_users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "cake_notify_lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "cake_notify_lambda_policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Scan",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "cake_notify" {
  function_name = "cake_notify"
  handler = "lambda_function.lambda_handler"
  runtime = "python3.9"
  role = aws_iam_role.lambda_exec_role.arn
  filename = "lambda_function.zip"
  source_code_hash = filebase64sha256("lambda_function.zip")

  environment {
    variables = {
      DYNAMODB_ENDPOINT = var.dynamodb_endpoint
      DYNAMODB_TABLE = aws_dynamodb_table.cake_notify_users.name
      DISCORD_CHANNEL_ID = var.discord_channel_id
      DISCORD_BOT_TOKEN = var.discord_bot_token
    }
  }
}

resource "aws_cloudwatch_event_rule" "daily_notification" {
  name = "cake_notify_daily"
  schedule_expression = "cron(0 0 * * ? *)" # 毎日0時
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule = aws_cloudwatch_event_rule.daily_notification.name
  target_id = "cake_notify_lambda"
  arn = aws_lambda_function.cake_notify.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cake_notify.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.daily_notification.arn
}
