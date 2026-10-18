"""Entry point used by the web UI (agent-ui/). The CLI in main.py is unaffected."""

from agent import CONFIRMATION_REQUIRED, TOOLS
from config import MODEL, SYSTEM_PROMPT
from database import initialize_database

NAME = "File & Notes Agent"
DESCRIPTION = "Saves and searches notes, and reads local files."


def setup():
    initialize_database()
