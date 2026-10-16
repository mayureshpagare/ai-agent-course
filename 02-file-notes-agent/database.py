import sqlite3
from pathlib import Path


DATA_DIRECTORY = Path("data")
DATABASE_PATH = DATA_DIRECTORY / "notes.db"

DEFAULT_CATEGORY = "general"

def get_connection():
    """Get a connection to the SQLite database."""
    DATA_DIRECTORY.mkdir(exist_ok=True)  # Ensure the data directory exists
    return sqlite3.connect(DATABASE_PATH)

def initialize_database():
    connection = get_connection()
    cursor = connection.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT 'general',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        '''
    )

    # Databases created before categories existed have no category column,
    # so add it in place instead of losing the existing notes.
    cursor.execute("PRAGMA table_info(notes)")
    columns = [row[1] for row in cursor.fetchall()]
    if "category" not in columns:
        cursor.execute(
            "ALTER TABLE notes ADD COLUMN category TEXT NOT NULL DEFAULT 'general'"
        )

    connection.commit()
    connection.close()
