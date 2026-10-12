# AI Agent Course

A series of command-line AI agents built with Python and a local
[Ollama](https://ollama.com/) model (`qwen3.5:9b`). Each folder is a
self-contained project.

| Project | Description |
| --- | --- |
| [01-calc-agent](01-calc-agent/) | Calculator agent that solves multi-step arithmetic with tool calls |
| [02-file-notes-agent](02-file-notes-agent/) | Reads local files and saves/searches notes in SQLite |
| [03-csv-analysis-agent](03-csv-analysis-agent/) | Answers questions about CSV files using pandas tools |

## Getting started

Each project has a `setup.sh` that installs Ollama, downloads the model, and
sets up a Python virtual environment (on Windows, run it from Git Bash):

```bash
cd 01-calc-agent
./setup.sh
```

The agents start the Ollama server automatically if it isn't already running.
