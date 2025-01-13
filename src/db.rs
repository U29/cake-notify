use chrono::NaiveDate;
use rusqlite::{Connection, Result};

pub struct User {
    pub username: String,
    pub user_id: String,
    pub display_name: Option<String>,
    pub birth_year: Option<i32>,
    pub birthday: NaiveDate,
    pub wishlist_url: Option<String>,
}

pub fn init_db() -> Result<Connection> {
    let conn = Connection::open("cake-notify.db")?;

    conn.execute(
        "CREATE TABLE IF NOT EXISTS users (
            username TEXT NOT NULL,
            user_id TEXT NOT NULL PRIMARY KEY,
            display_name TEXT,
            birth_year INTEGER,
            birthday TEXT NOT NULL,
            wishlist_url TEXT
        )",
        [],
    )?;

    conn.execute(
        "CREATE TABLE IF NOT EXISTS sync_status (
            last_sync TEXT NOT NULL
        )",
        [],
    )?;

    Ok(conn)
}

pub fn add_user(conn: &Connection, user: User) -> Result<()> {
    conn.execute(
        "INSERT OR REPLACE INTO users (username, user_id, display_name, birth_year, birthday, wishlist_url)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
        (&user.username, &user.user_id, &user.display_name, &user.birth_year, &user.birthday.to_string(), &user.wishlist_url),
    )?;
    Ok(())
}

pub fn get_users_with_upcoming_birthdays(conn: &Connection, days_until: i64) -> Result<Vec<User>> {
    let mut stmt = conn.prepare(
        "SELECT username, user_id, display_name, birth_year, birthday, wishlist_url
         FROM users
         WHERE DATE(birthday, 'start of year', '+' || (strftime('%Y', 'now') - strftime('%Y', birthday)) || ' years')
         BETWEEN DATE('now', '+' || ?1 || ' days') AND DATE('now', '+' || ?1 || ' days')"
    )?;

    let users = stmt
        .query_map([days_until], |row| {
            Ok(User {
                username: row.get(0)?,
                user_id: row.get(1)?,
                display_name: row.get(2)?,
                birth_year: row.get(3)?,
                birthday: NaiveDate::parse_from_str(&row.get::<_, String>(4)?, "%Y-%m-%d").unwrap(),
                wishlist_url: row.get(5)?,
            })
        })?
        .collect::<Result<Vec<_>>>()?;

    Ok(users)
}
