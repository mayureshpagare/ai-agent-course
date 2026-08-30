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

## Requirements

- Python 3.10 or newer
- [Ollama](https://ollama.com/) installed and running
- The `qwen3.5:9b` model available locally

## Setup

From the `01-calc-agent` directory, create and activate a virtual environment:

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

Make sure Ollama is running before starting the program.

## Run the agent

```powershell
python agent.py
```

Then enter a calculation at the prompt:

```text
You: What is 15% of 240, then add 12 to the result?
```

The program prints the tools selected by the model, their arguments and
results, followed by the agent's final explanation. Enter `exit` or `quit` to
end the session.

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
|-- agent.py          # Interactive agent and tool-calling loop
|-- tools.py          # Calculator tool implementations
|-- main.py           # Minimal Ollama chat example
|-- test1.py          # Earlier single-round agent experiment
|-- test2.py          # Multi-step agent experiment
`-- requirements.txt  # Pinned Python dependencies
```

## Configuration

The model and maximum number of tool-call rounds can be changed in `agent.py`:

```python
MODEL = "qwen3.5:9b"
MAX_TOOL_ROUNDS = 10
```

Although `tools.py` contains additional percentage-related helper functions,
only the six tools listed above are currently registered with the agent.
