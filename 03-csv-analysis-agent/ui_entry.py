"""Entry point used by the web UI (agent-ui/). The CLI in main.py is unaffected."""

from agent import TOOLS
from config import MODEL, SYSTEM_PROMPT

NAME = "CSV Analysis Agent"
DESCRIPTION = "Answers questions about data/issues.csv using pandas tools."
CONFIRMATION_REQUIRED = {}
