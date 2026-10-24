"""Calculator agent with a complete multi-step tool-calling loop."""

import inspect

from ollama import chat

import tools
from config import MAX_TOOL_ROUNDS, MODEL, OPTIONS


# Register every function defined in tools.py, in the order it appears there,
# so a newly added tool is never left out of the list by accident.
AVAILABLE_TOOLS = sorted(
    (
        function
        for _, function in inspect.getmembers(tools, inspect.isfunction)
        if function.__module__ == tools.__name__ and not function.__name__.startswith("_")
    ),
    key=lambda function: function.__code__.co_firstlineno,
)
TOOL_REGISTRY = {tool.__name__: tool for tool in AVAILABLE_TOOLS}


def execute_tool_call(tool_call) -> str:
    """Execute one model-requested tool call and return a text result."""
    function_name = tool_call.function.name
    arguments = tool_call.function.arguments

    print(f"\n[Tool selected: {function_name}]")
    print(f"[Arguments: {arguments}]")

    function = TOOL_REGISTRY.get(function_name)
    if function is None:
        result = f"Error: Unknown tool '{function_name}'."
    else:
        try:
            result = function(**arguments)
        except Exception as error:
            # Returning the error to the model lets it correct its arguments.
            result = f"Error: {error}"

    print(f"[Tool result: {result}]")
    return str(result)


def run_agent(messages: list) -> str:
    """Run model/tool rounds until the model produces the final response."""
    for _ in range(MAX_TOOL_ROUNDS):
        response = chat(
            model=MODEL,
            messages=messages,
            tools=AVAILABLE_TOOLS,
            options=OPTIONS,
        )
        messages.append(response.message)

        tool_calls = response.message.tool_calls or []
        if not tool_calls:
            return response.message.content

        # A response may request one tool or several independent tools.
        for tool_call in tool_calls:
            result = execute_tool_call(tool_call)
            messages.append(
                {
                    "role": "tool",
                    "tool_name": tool_call.function.name,
                    "content": result,
                }
            )

        # Continue immediately so the model can inspect the results, call the
        # next required tools, and eventually produce a complete final answer.

    return (
        f"Stopped after {MAX_TOOL_ROUNDS} tool rounds to prevent "
        "an accidental infinite loop."
    )
