# CSV Analysis Agent

An interactive command-line AI agent that uses a local Ollama model and
Python data tools to answer questions about CSV files. Instead of guessing
from a pasted sample, the agent loads the file with pandas and calls tools to
inspect columns, filter rows, aggregate values, and compute statistics. It then
explains the results in plain language.

> **Status:** planned. This README describes the intended design for the
> third project in the course. The source files listed below have not been
> written yet. Update this file as the tools are implemented.

## Features

- Tool-based analysis: every number in an answer comes from pandas, not the
  model
- Schema inspection: column names, data types, row count, and missing values
- Summary statistics for numeric columns (count, mean, min, max, std)
- Filtering, sorting, and top-N queries
- Group-by aggregations (sum, mean, count, min, max)
- Value counts for categorical columns
- Multi-step tool calling for compound questions
- Conversation history across prompts
- Friendly errors for unknown files, unknown columns, and invalid operations
- A safety limit on tool-call rounds to prevent infinite loops

## Requirements

- Python 3.10 or newer
- [Ollama](https://ollama.com/) installed and running
- The `qwen3.5:9b` model available locally

## Setup

From the `03-csv-analysis-agent` directory, create and activate a virtual
environment:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

Install the Python dependencies:

```powershell
pip install ollama pandas
pip freeze > requirements.txt
```

Download the model used by the agent:

```powershell
ollama pull qwen3.5:9b
```

Make sure Ollama is running before starting the program.

## Run the agent

Put one or more CSV files in the `data/` folder, then start the agent:

```powershell
python main.py
```

Example prompts:

```text
You: What CSV files are available?
You: Describe the columns in sales.csv.
You: What is the total revenue by region in sales.csv?
You: Show the 5 products with the highest unit price.
You: How many rows have a missing value in the email column?
```

The program prints each tool call with its arguments and result, then shows
the agent's final answer. Enter `exit` or `quit` to end the session.

## Planned tools

| Tool | Operation |
| --- | --- |
| `list_csv_files()` | Lists CSV files in the `data/` folder |
| `describe_csv(file_name)` | Returns columns, data types, row count, and missing-value counts |
| `preview_rows(file_name, n)` | Returns the first `n` rows (capped to keep responses small) |
| `summary_stats(file_name, column)` | Returns descriptive statistics for a numeric column |
| `value_counts(file_name, column, top_n)` | Returns the most frequent values in a column |
| `filter_rows(file_name, column, operator, value)` | Returns rows matching a condition (`==`, `!=`, `>`, `<`, `>=`, `<=`, `contains`) |
| `group_aggregate(file_name, group_by, column, operation)` | Groups by a column and applies `sum`, `mean`, `count`, `min`, or `max` |
| `top_n(file_name, column, n, ascending)` | Sorts by a column and returns the top or bottom `n` rows |

Each tool should return a short text or table string rather than a whole
DataFrame, so the model's context stays small even for large files.

## Project structure

```text
03-csv-analysis-agent/
|-- main.py           # Interactive chat loop
|-- agent.py          # Tool registry and tool-calling loop
|-- config.py         # Model name, data folder, limits, and system prompt
|-- csv_tools.py      # pandas-based analysis tools
|-- data/             # CSV files the agent can read
`-- requirements.txt  # Pinned Python dependencies
```

## Configuration

These settings are planned for `config.py`:

```python
MODEL = "qwen3.5:9b"
DATA_DIR = "data"
MAX_TOOL_ROUNDS = 10
MAX_ROWS_RETURNED = 20
```

The system prompt should tell the model to:

1. Call `describe_csv` before analyzing a file it has not inspected yet.
2. Use tools for every number. Never estimate or invent values.
3. Use exact column names as returned by `describe_csv`.
4. Explain tool errors clearly and suggest a valid alternative.
5. Use several tool calls for a multi-step question when needed.

## Safety notes

- Tools only read files inside `DATA_DIR`. Reject paths containing `..` or
  absolute paths.
- The agent is read-only. No tool modifies or deletes CSV files.
- Row output is capped by `MAX_ROWS_RETURNED`.
- Avoid `eval` or `DataFrame.query` with model-supplied strings. Map the
  operators explicitly instead.

## Ideas for later

- Chart generation with matplotlib, saved as PNG files
- Joining two CSV files on a shared column
- Date parsing and time-based grouping (by month or by year)
- Exporting filtered results to a new CSV file
