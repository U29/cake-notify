#!/bin/bash

# Terraformの初期化
terraform init

# Terraformの適用
terraform apply -auto-approve

# Lambda関数のデプロイ
aws lambda update-function-code \
  --function-name $(terraform output -raw lambda_function_name) \
  --zip-file fileb://lambda_function.zip \
  --endpoint-url http://localhost:4566
