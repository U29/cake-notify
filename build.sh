#!/bin/bash

# 仮想環境の作成
python3 -m venv venv
source venv/bin/activate

# 依存関係のインストール
pip install -r requirements.txt

# Lambda関数のzip化
mkdir -p package
cp lambda_function.py package/
cp -r venv/lib/python3.12/site-packages/* package/
cd package
zip -r ../lambda_function.zip .
cd ..
rm -rf package venv
