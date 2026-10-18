"""Copy this file into a new agent folder to make it appear in the web UI.

The worker runs with the agent folder as its working directory and uses the
folder's own .venv if it has one, so imports and relative paths behave the
same as when you run main.py from that folder.
"""

from agent import TOOLS               # list of plain Python functions the model can call
from config import MODEL, SYSTEM_PROMPT

NAME = "My New Agent"                 # shown in the sidebar
DESCRIPTION = "What this agent does, in one line."

# Tools that need an Approve click in the UI before they run: {tool_name: warning}
CONFIRMATION_REQUIRED = {}


def setup():
    """Optional one-time initialisation (create a database, etc.)."""
