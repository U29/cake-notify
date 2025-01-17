import os
import boto3
from datetime import datetime, timedelta
from dateutil import parser
from discord_webhook import DiscordWebhook
from pytz import timezone


def get_dynamodb_table():
    table_name = os.environ.get("DYNAMODB_TABLE", "birthdays")
    # endpoint_url はローカルでのテスト用。本番ではNoneになる
    endpoint_url = os.environ.get("DYNAMODB_ENDPOINT")
    dynamodb = boto3.resource("dynamodb", endpoint_url=endpoint_url)
    return dynamodb.Table(table_name)


def get_webhook_url():
    return os.environ["DISCORD_WEBHOOK_URL"]


def get_users_with_upcoming_birthdays():
    JST = timezone("Asia/Tokyo")
    today = datetime.now(JST).date()
    three_days_later = today + timedelta(days=3)

    table = get_dynamodb_table()
    response = table.scan()
    users = response.get("Items", [])

    upcoming_users = []
    for user in users:
        birthday = parser.parse(user["birthday"]).date()
        birthday_this_year = birthday.replace(year=today.year)
        if birthday_this_year < today:
            birthday_this_year = birthday_this_year.replace(year=today.year + 1)

        if today <= birthday_this_year <= three_days_later:
            days_until = (birthday_this_year - today).days
            user["days_until"] = days_until
            upcoming_users.append(user)

    return upcoming_users


def send_notification(user):
    days_until = user["days_until"]
    user_name = user["user_name"]
    url = user.get("url", "")

    if days_until == 0:
        message = (
            f"今日は{user_name}さんの誕生日です！おめでとう！\n欲しい物リスト → {url}"
        )
    else:
        message = f"{user_name}さんの誕生日まで、あと {days_until} 日です。"

    webhook = DiscordWebhook(url=get_webhook_url(), content=message)
    response = webhook.execute()
    print(f"Discord webhook response: {response}")


def lambda_handler(event, context):
    try:
        users = get_users_with_upcoming_birthdays()
        for user in users:
            send_notification(user)
        return {"statusCode": 200, "body": f"Sent notifications to {len(users)} users"}
    except Exception as e:
        print(f"Error: {str(e)}")
        return {"statusCode": 500, "body": str(e)}
