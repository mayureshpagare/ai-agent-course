# Agent UI

This is a chat interface in the style of ChatGPT or Claude for every agent in this repo. You pick an agent in the sidebar and chat with it. While the agent works, its tool calls show up as live cards. You approve dangerous tools with a button click. Chats are saved locally.

## Run

From the repo root:

```powershell
.\run_ui.ps1          # dev mode: http://localhost:5173 (hot reload)
.\run_ui.ps1 -Prod    # build once and serve everything from http://localhost:8000
```

The first run creates `agent-ui/backend/.venv` and installs the npm packages. Ollama must be installed, and each agent's own `.venv` must exist, just as it does for running `main.py`.

## How it works

```
React (Vite)  ──HTTP/SSE──▶  FastAPI backend (agent-ui/backend)
                                 │  one subprocess per agent, JSON lines over stdin/stdout
                                 ▼
                 <agent>/.venv python  worker.py  (cwd = agent folder)
                                 │  imports ui_entry.py → TOOLS, MODEL, SYSTEM_PROMPT
                                 ▼
                              Ollama
```

- Each agent runs with **its own venv**, with the agent folder as the working directory. Because of that, `data/...` paths and dependencies such as pandas work exactly as they do with `main.py`.
- `worker.py` contains one generic tool-calling loop. It stops after at most 10 rounds, and it pauses for an Approve/Deny decision on the tools listed in `CONFIRMATION_REQUIRED`.
- Chat history is stored in `agent-ui/backend/data/history.db` (SQLite). The system prompt is not stored, so when you edit a prompt the change also applies to old chats.
- The `main.py` CLIs are unchanged and still work.

## Adding a new agent

1. Create the agent folder at the repo root, for example `04-my-agent/`, with its tools, `.venv`, and so on.
2. Copy [templates/ui_entry.py](templates/ui_entry.py) into that folder and fill in `NAME`, `DESCRIPTION`, `TOOLS`, `MODEL` and `SYSTEM_PROMPT`.
3. Refresh the browser. The new agent appears in the sidebar.
