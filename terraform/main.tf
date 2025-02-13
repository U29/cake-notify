terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "cake-notify-infra"
    key    = "terraform/terraform.tfstate"
    region = "ap-northeast-1"
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

resource "aws_dynamodb_table" "cake_notify" {
  name         = "cake-notify"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "birthday"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "birthday"
    type = "S"
  }
}

resource "aws_lambda_function" "cake_notifier" {
  function_name    = "cake-notifier"
  role             = var.lambda_role_arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 10
  filename         = "${path.module}/../lambda/lambda_function.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda/lambda_function.zip")

  environment {
    variables = {
      DYNAMODB_TABLE      = aws_dynamodb_table.cake_notify.name
      DISCORD_WEBHOOK_URL = var.discord_webhook_url
    }
  }
}

resource "aws_scheduler_schedule" "cake_notify_daily" {
  name                         = "cake-notify-daily"
  group_name                   = "cake-notify"
  schedule_expression          = "cron(0 0 * * ? *)"
  schedule_expression_timezone = "Asia/Tokyo"
  state                        = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.cake_notifier.arn
    role_arn = var.scheduler_role_arn

    retry_policy {
      maximum_event_age_in_seconds = 86400
      maximum_retry_attempts       = 185
    }
  }
}
