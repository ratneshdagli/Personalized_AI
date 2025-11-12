import sqlite3
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


DB_PATH = Path(__file__).resolve().parent.parent.parent / "personalized_ai_companion.db"


def get_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    conn = get_connection()
    cur = conn.cursor()

    # Users
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS user_profile (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            email TEXT,
            preferences_json TEXT,
            persona_json TEXT
        );
        """
    )

    # Notifications
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            app_name TEXT NOT NULL,
            title TEXT,
            message TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            priority REAL,
            category TEXT,
            is_relevant INTEGER,
            summary TEXT
        );
        """
    )

    conn.commit()
    conn.close()


def insert_user_profile(name: str, email: str, preferences_json: str, persona_json: str) -> int:
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO user_profile (name, email, preferences_json, persona_json) VALUES (?, ?, ?, ?)",
        (name, email, preferences_json, persona_json),
    )
    conn.commit()
    user_id = cur.lastrowid
    conn.close()
    return user_id


def get_user_profile() -> Optional[sqlite3.Row]:
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT * FROM user_profile ORDER BY id DESC LIMIT 1")
    row = cur.fetchone()
    conn.close()
    return row


def upsert_user_profile(name: str, email: str, preferences_json: str, persona_json: str) -> int:
    existing = get_user_profile()
    if existing is None:
        return insert_user_profile(name, email, preferences_json, persona_json)

    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        "UPDATE user_profile SET name=?, email=?, preferences_json=?, persona_json=? WHERE id=?",
        (name, email, preferences_json, persona_json, existing["id"]),
    )
    conn.commit()
    user_id = existing["id"]
    conn.close()
    return user_id


def insert_notification(rec: Dict[str, Any]) -> int:
    conn = get_connection()
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO notifications (
            app_name, title, message, timestamp, priority, category, is_relevant, summary
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            rec.get("app_name"),
            rec.get("title"),
            rec.get("message"),
            rec.get("timestamp"),
            rec.get("priority"),
            rec.get("category"),
            1 if rec.get("is_relevant") else 0,
            rec.get("summary"),
        ),
    )
    conn.commit()
    row_id = cur.lastrowid
    conn.close()
    return row_id


def list_notifications(limit: int = 50) -> List[Dict[str, Any]]:
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT * FROM notifications ORDER BY id DESC LIMIT ?", (limit,))
    rows = cur.fetchall()
    conn.close()
    return [dict(r) for r in rows]


