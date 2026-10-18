"""Entry point used by the web UI (agent-ui/). The CLI in main.py is unaffected."""

from agent import AVAILABLE_TOOLS
from config import MODEL, SYSTEM_PROMPT

NAME = "Calculator Agent"
DESCRIPTION = "Solves multi-step arithmetic using calculator tools."
TOOLS = AVAILABLE_TOOLS
CONFIRMATION_REQUIRED = {}
