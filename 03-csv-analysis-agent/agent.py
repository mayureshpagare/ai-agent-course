from ollama import chat

from config import MODEL, SYSTEM_PROMPT

from csv_tools import (
    inspect_csv,
    preview_csv,
    count_rows,
    filter_rows,
    search_text,
    count_by_column,
    summarize_numeric_column,
    summarize_by_group,
    count_by_column_filtered,
)

TOOLS = [
    inspect_csv,
    preview_csv,
    count_rows,
    filter_rows,
    search_text,
    count_by_column,
    summarize_numeric_column,
    summarize_by_group,
    count_by_column_filtered,
]

TOOL_REGISTRY = {
    tool.__name__: tool
    for tool in TOOLS
}

def run_agent(messages:list[dict]) -> str:
    while True:
        response = chat(
            model=MODEL,
            messages=messages,
            tools=TOOLS
        )

        messages.append(response.message)

        if not response.message.tool_calls:
            return response.message.content

        for tool_call in response.message.tool_calls:
            tool_name = tool_call.function.name
            arguements = tool_call.function.arguments
            print(f"Calling tool: {tool_name} with arguments: {arguements}")
            tool = TOOL_REGISTRY.get(tool_name)

            if tool is None:
                messages.append({
                    "role": "assistant",
                    "content": f"Error: Tool '{tool_name}' not found."
                })
                
            else:
                try:
                    result= tool(**arguements)
                except Exception as error:
                    messages.append({
                        "role": "assistant",
                        "content": f"Error: Tool '{tool_name}' failed with error: {error}"
                    })
            print(f"Tool result: {result}")
            messages.append({
                "role": "tool",
                "name": tool_name,
                "content": str(result)
            })