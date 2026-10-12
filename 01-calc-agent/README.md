# Calculator Agent

An interactive command-line AI agent that uses a local Ollama model and
Python calculator tools to solve arithmetic problems. The agent supports
multi-step calculations, keeps conversation history, and shows each tool call
and result before presenting its final answer.

## Features

- Tool-based arithmetic instead of model-generated calculations
- Addition, subtraction, multiplication, division, powers, and percentages
- Multi-step tool calling for compound problems
- Conversation history across prompts
- Friendly handling of tool errors such as division by zero
- A 10-round safety limit to prevent accidental infinite tool loops
- Starts the Ollama server automatically if it is not already running

## Requirements

- Python 3.10 or newer
- [Ollama](https://ollama.com/)
- The `qwen3.5:9b` model

`setup.sh` installs Ollama and the model for you if they are missing.

## Setup

### Quick setup

From the `01-calc-agent` directory (on Windows, use Git Bash):

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

```powershell
python agent.py
```

On startup, the agent checks that the Ollama server is reachable. If it is
not, the agent launches `ollama serve` in the background and pulls the model
if it is missing. You do not need to run `ollama run` first.

Then enter a calculation at the prompt:

```text
You: What is 15% of 240, then add 12 to the result?
```

The program prints the tools selected by the model, their arguments and
results, followed by the agent's final explanation. Enter `exit` or `quit` to
end the session.

## How it works

1. The user's message is added to the conversation history.
2. The history and the tool list are sent to the model.
3. If the model requests tool calls, each one is run through `TOOL_REGISTRY`
   and its result (or error message) is appended to the history.
4. Steps 2 and 3 repeat until the model replies without tool calls, or until
   `MAX_TOOL_ROUNDS` is reached.

Tool errors are returned to the model as text instead of crashing the
program, so the model can correct its arguments and try again.

## Available tools

| Tool | Operation |
| --- | --- |
| `add(a, b)` | Adds two numbers |
| `subtract(a, b)` | Subtracts `b` from `a` |
| `multiply(a, b)` | Multiplies two numbers |
| `divide(a, b)` | Divides `a` by `b` and rejects a zero divisor |
| `power(a, b)` | Raises `a` to the power of `b` |
| `percentage(value, percent)` | Calculates a percentage of a value |

## Project structure

```text
01-calc-agent/
|-- agent.py          # Interactive agent and multi-step tool-calling loop
|-- tools.py          # Calculator tool implementations
|-- ollama_setup.py   # Starts the Ollama server and pulls the model if needed
|-- setup.sh          # One-shot installer for Ollama, the model, and Python deps
|-- main.py           # Minimal Ollama chat example (no tools)
|-- test1.py          # Earlier single-round agent experiment
|-- test2.py          # Multi-step agent experiment (precursor to agent.py)
`-- requirements.txt  # Pinned Python dependencies
```

## Configuration

The model and maximum number of tool-call rounds can be changed in `agent.py`:

```python
MODEL = "qwen3.5:9b"
MAX_TOOL_ROUNDS = 10
```

## Future scope

- Register the additional percentage and tax tools already drafted in
  `tools.py`: discounted price, percentage difference, percentage of total,
  percentage change, and GST
- More operations such as square roots, rounding, and averages
- Stronger input validation and error handling for tool arguments
