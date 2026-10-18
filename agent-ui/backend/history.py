"""Chat history stored in SQLite (agent-ui/backend/data/history.db)."""

import json
import sqlite3
import threading
import time
import uuid
from pathlib import Path

DATA_DIRECTORY = Path(__file__).with_name("data")
DATABASE_PATH = DATA_DIRECTORY / "history.db"

_lock = threading.Lock()
_connection: sqlite3.Connection | None = None


def _db() -> sqlite3.Connection:
    global _connection
    if _connection is None:
        DATA_DIRECTORY.mkdir(exist_ok=True)
        _connection = sqlite3.connect(DATABASE_PATH, check_same_thread=False)
        _connection.row_factory = sqlite3.Row
        _connection.executescript("""
            CREATE TABLE IF NOT EXISTS conversations (
                id TEXT PRIMARY KEY,
                agent_id TEXT NOT NULL,
                title TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                conversation_id TEXT NOT NULL
                    REFERENCES conversations(id) ON DELETE CASCADE,
                json TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_messages_conversation
                ON messages(conversation_id, id);
        """)
        _connection.execute("PRAGMA foreign_keys = ON")
    return _connection


def _row(row) -> dict | None:
    return dict(row) if row else None


def list_conversations(agent_id: str | None = None) -> list[dict]:
    with _lock:
        if agent_id:
            rows = _db().execute(
                "SELECT * FROM conversations WHERE agent_id = ? ORDER BY updated_at DESC",
                (agent_id,))
        else:
            rows = _db().execute("SELECT * FROM conversations ORDER BY updated_at DESC")
        return [dict(r) for r in rows]


def create_conversation(agent_id: str, title: str = "New chat") -> dict:
    now = time.time()
    conversation = {"id": uuid.uuid4().hex, "agent_id": agent_id, "title": title,
                    "created_at": now, "updated_at": now}
    with _lock, _db():
        _db().execute(
            "INSERT INTO conversations VALUES (:id, :agent_id, :title, :created_at, :updated_at)",
            conversation)
    return conversation


def get_conversation(conversation_id: str) -> dict | None:
    with _lock:
        return _row(_db().execute(
            "SELECT * FROM conversations WHERE id = ?", (conversation_id,)).fetchone())


def rename_conversation(conversation_id: str, title: str) -> None:
    with _lock, _db():
        _db().execute("UPDATE conversations SET title = ? WHERE id = ?",
                      (title, conversation_id))


def delete_conversation(conversation_id: str) -> None:
    with _lock, _db():
        _db().execute("DELETE FROM messages WHERE conversation_id = ?", (conversation_id,))
        _db().execute("DELETE FROM conversations WHERE id = ?", (conversation_id,))


def get_messages(conversation_id: str) -> list[dict]:
    with _lock:
        rows = _db().execute(
            "SELECT json FROM messages WHERE conversation_id = ? ORDER BY id",
            (conversation_id,))
        return [json.loads(r["json"]) for r in rows]


def add_messages(conversation_id: str, messages: list[dict]) -> None:
    with _lock, _db():
        _db().executemany(
            "INSERT INTO messages (conversation_id, json) VALUES (?, ?)",
            [(conversation_id, json.dumps(m, default=str)) for m in messages])
        _db().execute("UPDATE conversations SET updated_at = ? WHERE id = ?",
                      (time.time(), conversation_id))
