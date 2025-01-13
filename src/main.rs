use db::{get_users_with_upcoming_birthdays, init_db};
use google_sheets4::Sheets;
use serenity::framework::standard::{
    macros::{command, group},
    StandardFramework,
};
use serenity::model::id::ChannelId;
use serenity::model::prelude::*;
use serenity::prelude::*;
use sheets::{create_sheets_client, sync_from_sheets, SheetConfig};
use std::env;
use std::time::Duration;
use tokio::time::sleep;

mod db;
mod sheets;

struct Handler;

#[group]
struct General;

#[tokio::main]
async fn main() {
    dotenv::dotenv().expect("Failed to load .env file");

    let token = env::var("DISCORD_TOKEN").expect("Expected a token in the environment");

    let framework = StandardFramework::new().group(&GENERAL_GROUP);

    let mut client = Client::builder(&token)
        .event_handler(Handler)
        .framework(framework)
        .await
        .expect("Error creating client");

    let conn = init_db().expect("Failed to initialize database");

    // Initialize Google Sheets client
    let sheets_client = create_sheets_client()
        .await
        .expect("Failed to create Google Sheets client");

    let sheet_config = SheetConfig {
        spreadsheet_id: env::var("SPREADSHEET_ID").expect("SPREADSHEET_ID must be set"),
        range: "Sheet1!A2:F".to_string(),
    };

    // Initial sync
    sync_from_sheets(&sheets_client, &sheet_config, &conn)
        .await
        .expect("Failed to sync from Google Sheets");

    tokio::spawn(async move {
        loop {
            check_and_notify(&conn).await;
            sleep(Duration::from_secs(86400)).await; // 24 hours
        }
    });

    if let Err(why) = client.start().await {
        println!("Client error: {:?}", why);
    }
}

async fn check_and_notify(conn: &rusqlite::Connection) {
    for days in 1..=3 {
        if let Ok(users) = get_users_with_upcoming_birthdays(conn, days) {
            for user in users {
                let message = if days == 0 {
                    format!(
                        "今日は{}さんの{}歳の誕生日です！おめでとう！\n欲しい物リスト → {}",
                        user.display_name.unwrap_or(user.username),
                        user.birth_year.map_or(String::new(), |y| format!(
                            "{}",
                            chrono::Local::now().year() - y
                        )),
                        user.wishlist_url.unwrap_or_default()
                    )
                } else {
                    format!(
                        "{}さんの誕生日まで、あと{}日です。",
                        user.display_name.unwrap_or(user.username),
                        days
                    )
                };

                if let Err(why) = ChannelId(
                    env::var("CHANNEL_ID")
                        .expect("Expected CHANNEL_ID in environment")
                        .parse()
                        .expect("CHANNEL_ID must be a valid number"),
                )
                .say(&message)
                .await
                {
                    eprintln!("Error sending message: {:?}", why);
                }
            }
        }
    }
}
