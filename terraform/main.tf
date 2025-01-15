provider "aws" {
  region = "us-east-1"
  access_key = "test"
  secret_key = "test"
  skip_credentials_validation = true
  skip_requesting_account_id = true
  skip_metadata_api_check = true
  s3_use_path_style = true
  
  endpoints {
    dynamodb = "http://localstack:4566"
    lambda   = "http://localstack:4566"
    events   = "http://localstack:4566"
    sts      = "http://localstack:4566"
    iam      = "http://localstack:4566"
  }
}

resource "aws_dynamodb_table" "birthdays" {
  name           = "birthdays"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }
}

resource "aws_lambda_function" "notify_birthday" {
  function_name = "notify_birthday"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.lambda_exec.arn
  filename      = "/lambda/lambda_function.zip"

  environment {
    variables = {
      DISCORD_WEBHOOK_URL = var.discord_webhook_url
      DYNAMODB_ENDPOINT   = "http://localstack:4566"
    }
  }
}

resource "aws_cloudwatch_event_rule" "daily_9am" {
  name                = "daily-9am"
  schedule_expression = "cron(0 9 * * ? *)"
}

resource "aws_cloudwatch_event_target" "trigger_lambda" {
  rule      = aws_cloudwatch_event_rule.daily_9am.name
  target_id = "NotifyBirthday"
  arn       = aws_lambda_function.notify_birthday.arn
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda-role"

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
  name = "lambda-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Scan",
          "dynamodb:Query",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notify_birthday.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_9am.arn
}
