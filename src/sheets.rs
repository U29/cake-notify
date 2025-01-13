use chrono::NaiveDate;
use db::{add_user, User};
use google_sheets4::api::ValueRange;
use google_sheets4::{hyper, hyper_rustls, Sheets};
use std::error::Error;

pub struct SheetConfig {
    pub spreadsheet_id: String,
    pub range: String,
}

pub async fn sync_from_sheets(
    hub: &Sheets<hyper_rustls::HttpsConnector<hyper::client::HttpConnector>>,
    config: &SheetConfig,
    conn: &rusqlite::Connection,
) -> Result<(), Box<dyn Error>> {
    let response = hub
        .spreadsheets()
        .values_get(&config.spreadsheet_id, &config.range)
        .doit()
        .await?;

    if let Some(values) = response.1.values {
        for row in values {
            if row.len() >= 6 {
                let user = User {
                    username: row[0].to_string(),
                    user_id: row[1].to_string(),
                    display_name: if row[2].is_empty() {
                        None
                    } else {
                        Some(row[2].to_string())
                    },
                    birth_year: if row[3].is_empty() {
                        None
                    } else {
                        Some(row[3].parse()?)
                    },
                    birthday: NaiveDate::parse_from_str(&row[4], "%Y-%m-%d")?,
                    wishlist_url: if row[5].is_empty() {
                        None
                    } else {
                        Some(row[5].to_string())
                    },
                };
                add_user(conn, user)?;
            }
        }
    }

    Ok(())
}

pub async fn create_sheets_client(
) -> Result<Sheets<hyper_rustls::HttpsConnector<hyper::client::HttpConnector>>, Box<dyn Error>> {
    let secret = yup_oauth2::read_service_account_key("credentials.json")
        .await
        .map_err(|e| format!("Failed to read credentials: {}", e))?;

    let auth = yup_oauth2::ServiceAccountAuthenticator::builder(secret)
        .build()
        .await
        .map_err(|e| format!("Failed to create authenticator: {}", e))?;

    Ok(Sheets::new(
        hyper::Client::builder().build(hyper_rustls::HttpsConnector::with_native_roots()),
        auth,
    ))
}
