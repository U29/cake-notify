import os
import boto3
from datetime import datetime, timedelta
import discord
from dotenv import load_dotenv

# 環境変数の読み込み
load_dotenv()

# DynamoDBクライアントの初期化
dynamodb = boto3.resource("dynamodb", endpoint_url=os.getenv("DYNAMODB_ENDPOINT"))
table = dynamodb.Table(os.getenv("DYNAMODB_TABLE"))

# Discordクライアントの初期化
intents = discord.Intents.default()
client = discord.Client(intents=intents)


def calculate_days_until_birthday(birthday):
    today = datetime.now().date()
    next_birthday = (
        datetime.strptime(birthday, "%Y-%m-%d").date().replace(year=today.year)
    )

    if next_birthday < today:
        next_birthday = next_birthday.replace(year=today.year + 1)

    return (next_birthday - today).days


def create_message(user, days_until_birthday):
    if days_until_birthday == 0:
        age = datetime.now().year - int(user["birthday"][:4])
        return (
            f"今日は{user['user_name']}さんの{age}歳の誕生日です！おめでとう！\n"
            f"欲しい物リスト → {user['url']}"
        )
    elif days_until_birthday <= 3:
        return (
            f"{user['user_name']}さんの誕生日まで、あと {days_until_birthday} 日です。"
        )


def lambda_handler(event, context):
    # 全ユーザーをスキャン
    response = table.scan()
    users = response.get("Items", [])

    # Discordに通知
    for user in users:
        days_until_birthday = calculate_days_until_birthday(user["birthday"])
        if days_until_birthday <= 3:
            message = create_message(user, days_until_birthday)
            if message:
                channel = client.get_channel(int(os.getenv("DISCORD_CHANNEL_ID")))
                if channel:
                    channel.send(message)

    return {"statusCode": 200, "body": "Notifications sent successfully"}
