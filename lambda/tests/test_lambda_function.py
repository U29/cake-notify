import os
import pytest
import boto3
from datetime import datetime, timedelta
from moto import mock_aws
from lambda_function import lambda_handler
from pytz import timezone


@pytest.fixture
def dynamodb_table():
    with mock_aws():
        dynamodb = boto3.resource("dynamodb")
        table = dynamodb.create_table(
            TableName="birthdays",
            KeySchema=[
                {"AttributeName": "id", "KeyType": "HASH"},
            ],
            AttributeDefinitions=[
                {"AttributeName": "id", "AttributeType": "S"},
            ],
            ProvisionedThroughput={"ReadCapacityUnits": 5, "WriteCapacityUnits": 5},
        )
        yield table


def create_test_data(table, days_offset=0):
    """テストデータを作成するヘルパー関数

    Args:
        table: DynamoDBテーブル
        days_offset: 今日からの日数オフセット（デフォルト0）
    """
    JST = timezone("Asia/Tokyo")
    today = datetime.now(JST).date() + timedelta(days=days_offset)
    test_data = [
        # 今日の誕生日
        {
            "id": "1",
            "user_name": "User1",
            "birthday": str(today),
            "url": "https://example.com/1",
        },
        # 1日後の誕生日
        {
            "id": "2",
            "user_name": "User2",
            "birthday": str(today + timedelta(days=1)),
            "url": "https://example.com/2",
        },
        # 2日後の誕生日
        {
            "id": "3",
            "user_name": "User3",
            "birthday": str(today + timedelta(days=2)),
            "url": "https://example.com/3",
        },
        # 3日後の誕生日
        {
            "id": "4",
            "user_name": "User4",
            "birthday": str(today + timedelta(days=3)),
            "url": "https://example.com/4",
        },
        # 4日後の誕生日（範囲外）
        {
            "id": "5",
            "user_name": "User5",
            "birthday": str(today + timedelta(days=4)),
            "url": "https://example.com/5",
        },
        # 1日前の誕生日（範囲外）
        {
            "id": "6",
            "user_name": "User6",
            "birthday": str(today - timedelta(days=1)),
            "url": "https://example.com/6",
        },
    ]

    with table.batch_writer() as batch:
        for item in test_data:
            batch.put_item(Item=item)


def test_data_insertion(dynamodb_table):
    create_test_data(dynamodb_table)
    response = dynamodb_table.scan()
    assert len(response["Items"]) == 6  # テストデータは6件作成している


def test_data_filtering(dynamodb_table):
    create_test_data(dynamodb_table)
    from lambda_function import get_users_with_upcoming_birthdays

    # テーブル名を設定
    os.environ["DYNAMODB_TABLE"] = "birthdays"

    # 今日の日付を基準にテスト
    users = get_users_with_upcoming_birthdays()

    # 範囲外のデータがフィルタリングされていることを確認
    assert len(users) == 4  # 4件のみが範囲内

    # 各ユーザーのIDを確認
    user_ids = {user["id"] for user in users}
    assert "5" not in user_ids  # 4日後のデータは含まれない
    assert "6" not in user_ids  # 1日前のデータは含まれない


def test_get_birthday_users(dynamodb_table):
    create_test_data(dynamodb_table)
    from lambda_function import get_users_with_upcoming_birthdays

    # テーブル名を設定
    os.environ["DYNAMODB_TABLE"] = "birthdays"

    # 今日の日付を基準にテスト
    users = get_users_with_upcoming_birthdays()
    assert len(users) == 4  # テストデータは4件作成している

    # 各ユーザーのdays_untilが正しく設定されているか確認
    for user in users:
        assert "days_until" in user
        assert 0 <= user["days_until"] <= 3


def test_lambda_handler(dynamodb_table):
    create_test_data(dynamodb_table)
    from lambda_function import lambda_handler

    # 環境変数を設定
    os.environ["DYNAMODB_TABLE"] = os.environ.get("DYNAMODB_TABLE", "birthdays")
    os.environ["DISCORD_WEBHOOK_URL"] = os.environ.get(
        "DISCORD_WEBHOOK_URL", "https://example.com"
    )

    # Lambdaハンドラを実行
    result = lambda_handler({}, {})

    # 結果を検証
    assert result["statusCode"] == 200
    assert "Sent notifications to 4 users" in result["body"]
