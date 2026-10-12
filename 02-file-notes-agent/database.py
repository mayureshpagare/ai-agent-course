import sqlite3
from pathlib import Path


DATA_DIRECTORY = Path("data")
DATABASE_PATH = DATA_DIRECTORY / "notes.db"

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
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        '''
    )
    connection.commit()
    connection.close()