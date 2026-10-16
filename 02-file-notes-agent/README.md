# File & Notes Agent

An interactive command-line AI agent that uses a local Ollama model to read
files on your computer and manage persistent notes. Notes are stored in a
SQLite database, so anything you ask the agent to remember is still there the
next time you start it.

## Features

- Persistent notes stored in SQLite (`data/notes.db`)
- Save, list, search, and delete notes through natural language
- Note categories (for example `database`, `docker`, `learning`)
- Duplicate detection: saving the same note twice returns the existing ID
- List directory contents, find files by name in subfolders, read UTF-8 text
  files (with a size limit), and inspect file metadata
- Structured (JSON) tool results
- Input validation in the tools, and a confirmation prompt before deleting
  all notes
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
| `save_note(content, category)` | Saves a new note (category defaults to `general`); if identical content exists, returns that note's ID instead |
| `list_notes()` | Lists all notes with their IDs, categories, and creation times |
| `search_notes(keyword)` | Finds notes whose content contains the keyword |
| `get_notes_by_category(category)` | Lists the notes in one category |
| `delete_note(note_id)` | Deletes the note with the given ID |
| `delete_all_notes()` | Deletes every note, only after you type `yes` at the approval prompt |

### File tools (`file_tools.py`)

| Tool | Operation |
| --- | --- |
| `list_files(directory)` | Lists files and folders in a directory (defaults to `.`) |
| `find_files(directory, filename)` | Searches a folder and its subfolders for a file name (wildcards allowed); skips `.git`, `.venv`, `__pycache__`, `node_modules`; returns at most 100 matches |
| `read_file(file_path, max_characters)` | Returns up to `max_characters` (default 10,000, capped at 50,000) of a UTF-8 text file without loading the rest, and reports whether it was truncated |
| `get_file_info(file_path)` | Returns a file's extension, size, folder, and last-modified time |

## Database

`database.py` creates a single `notes` table:

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `INTEGER` | Primary key, auto-incremented |
| `content` | `TEXT` | The note text |
| `category` | `TEXT` | Topic label, lowercase; defaults to `general` |
| `created_at` | `TIMESTAMP` | Defaults to the current time (UTC) |

The `data/` folder is listed in `.gitignore`, so your notes are never
committed. A fresh clone starts with an empty database. An existing database
created before categories were added gets the `category` column on the next
start, and its old notes are put in `general`.

## Tool results and validation

Every tool returns a dictionary or a list of dictionaries, for example
`{"status": "saved", "id": 3, "content": "...", "category": "docker"}` or
`{"error": "Invalid note ID: -5. Note IDs are positive integers."}`.
`agent.py` converts them to JSON before sending them back to the model.

Inputs are checked in Python rather than left to the model: missing files,
folders passed where a file is expected, non-positive or non-numeric note IDs,
empty search keywords, empty notes, and oversized read limits all return an
`error` result instead of running.

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
- `delete_all_notes` is listed in `CONFIRMATION_REQUIRED` in `agent.py`. Before
  it runs, the program asks you to type `yes`; any other answer cancels it and
  tells the model nothing was changed. Reads and single-note deletes run
  without a prompt.
- File reads are limited to 50,000 characters, so a very large file cannot
  fill memory or the conversation.
- File tools read from the paths you give them, so avoid asking the agent to
  open sensitive files.

## Future scope

- Register the note tools already drafted in `note_tools.py`: counting notes
  and updating an existing note
- Restrict file tools to an allowed folder
- A limit on tool-call rounds, as in the calculator agent

## Tool selection exercise

Before sending each prompt, predict which tool the model will call, then
compare with the `Calling tool:` line the program prints.

| Prompt | Expected tool |
| --- | --- |
| Remember that Redis runs on port 6379. | `save_note` (category such as `database` or `redis`) |
| What do you remember about Redis? | `search_notes("Redis")` |
| List everything you've stored. | `list_notes` |
| Delete the Redis note. | `search_notes` to find the ID, then `delete_note` |
| What's inside sample.txt? | `read_file` |
| How big is sample.txt? | `get_file_info` |
| What files are here? | `list_files` |
