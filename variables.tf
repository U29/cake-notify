variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "dynamodb_endpoint" {
  description = "DynamoDB endpoint"
  type        = string
}

variable "lambda_endpoint" {
  description = "Lambda endpoint"
  type        = string
}

variable "events_endpoint" {
  description = "EventBridge endpoint"
  type        = string
}

variable "iam_endpoint" {
  description = "IAM endpoint"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
  default     = "cake-notify-users"
}

variable "lambda_zip_path" {
  description = "Path to Lambda function zip file"
  type        = string
  default     = "lambda_function.zip"
}

variable "discord_channel_id" {
  description = "Discord channel ID for notifications"
  type        = string
}

variable "discord_bot_token" {
  description = "Discord bot token"
  type        = string
  sensitive   = true
}
