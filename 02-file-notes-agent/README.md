# File & Notes Agent

An interactive command-line AI agent that uses a local Ollama model to read
files on your computer and manage persistent notes. Notes are stored in a
SQLite database, so anything you ask the agent to remember is still there the
next time you start it.

## Features

- Persistent notes stored in SQLite (`data/notes.db`)
- Save, list, search, and delete notes through natural language
- List directory contents, read UTF-8 text files, and inspect file metadata
- Multi-step tool calling, for example reading a file and then saving a note
  about it
- Conversation history across prompts
- Tool errors are returned to the model instead of crashing the program
- Starts the Ollama server automatically if it is not already running

## Requirements

- Python 3.10 or newer
- [Ollama](https://ollama.com/)
- The `qwen3.5:9b` model

`setup.sh` installs Ollama and the model for you if they are missing.

## Setup

### Quick setup

From the `02-file-notes-agent` directory (on Windows, use Git Bash):

```bash
./setup.sh
```

The script installs Ollama, starts the server, downloads `qwen3.5:9b`,
creates a `.venv` virtual environment, and installs `requirements.txt`. Steps
that are already done are skipped, so it is safe to re-run. To use a
different model, run `MODEL=other:tag ./setup.sh`.

### Manual setup

Create and activate a virtual environment:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

Install the Python dependencies:

```powershell
pip install -r requirements.txt
```

Download the model used by the agent:

```powershell
ollama pull qwen3.5:9b
```

## Run the agent

Run it from the `02-file-notes-agent` directory, because the database and
relative file paths are resolved from the current directory:

```powershell
python main.py
```

On startup, the agent checks that the Ollama server is reachable (starting
`ollama serve` in the background if needed) and creates `data/notes.db` if it
does not exist yet.

Example prompts:

```text
You: What files are in this folder?
You: Read sample.txt and tell me which port the database uses.
You: Remember that the project database runs on port 5433.
You: What notes do I have about the database?
You: Show all my notes.
You: Delete note 2.
```

The program prints each tool call with its arguments and result, then shows
the agent's final answer. Enter `exit` or `quit` to end the session.

## How it works

1. `main.py` initializes the database and starts the chat loop.
2. Each user message is added to the conversation history and passed to
   `run_agent` in `agent.py`.
3. The model receives the history and the tool list. If it requests tool
   calls, each one is looked up in `TOOL_REGISTRY`, run, and its result is
   appended to the history.
4. This repeats until the model replies without tool calls; that reply is
   printed as the answer.

The system prompt in `config.py` tells the model to use tools instead of
guessing, to save notes only when explicitly asked, and to never delete a
note unless the user asks.

## Available tools

### Note tools (`note_tools.py`)

| Tool | Operation |
| --- | --- |
| `save_note(content)` | Saves a new note and returns its ID |
| `list_notes()` | Lists all notes with their IDs and creation times |
| `search_notes(keyword)` | Finds notes whose content contains the keyword |
| `delete_note(note_id)` | Deletes the note with the given ID |

### File tools (`file_tools.py`)

| Tool | Operation |
| --- | --- |
| `list_files(directory)` | Lists files and folders in a directory (defaults to `.`) |
| `read_file(file_path)` | Returns the contents of a UTF-8 text file |
| `get_file_info(file_path)` | Returns a file's extension, size, folder, and last-modified time |

## Database

`database.py` creates a single `notes` table:

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `INTEGER` | Primary key, auto-incremented |
| `content` | `TEXT` | The note text |
| `created_at` | `TIMESTAMP` | Defaults to the current time (UTC) |

The `data/` folder is listed in `.gitignore`, so your notes are never
committed. A fresh clone starts with an empty database.

## Project structure

```text
02-file-notes-agent/
|-- main.py           # Entry point: startup checks and interactive chat loop
|-- agent.py          # Tool registry and tool-calling loop
|-- config.py         # Model name and system prompt
|-- database.py       # SQLite connection and table setup
|-- note_tools.py     # Note tools (save, list, search, delete, ...)
|-- file_tools.py     # File tools (list, read, info)
|-- ollama_setup.py   # Starts the Ollama server and pulls the model if needed
|-- setup.sh          # One-shot installer for Ollama, the model, and Python deps
|-- sample.txt        # Sample file for trying the file tools
|-- data/             # Created at runtime; holds notes.db (git-ignored)
`-- requirements.txt  # Pinned Python dependencies
```

## Configuration

The model and system prompt live in `config.py`:

```python
MODEL = "qwen3.5:9b"
SYSTEM_PROMPT = """..."""
```

The database location is set in `database.py`:

```python
DATA_DIRECTORY = Path("data")
DATABASE_PATH = DATA_DIRECTORY / "notes.db"
```

## Safety notes

- File tools are read-only; the agent cannot modify or delete files on disk.
- Notes are deleted only when the user explicitly asks.
- File tools read from the paths you give them, so avoid asking the agent to
  open sensitive files.

## Future scope

- Register the note tools already drafted in `note_tools.py`: counting notes
  and updating an existing note
- Restrict file tools to an allowed folder
- A limit on tool-call rounds, as in the calculator agent
- Stronger error and exception handling around tool calls
