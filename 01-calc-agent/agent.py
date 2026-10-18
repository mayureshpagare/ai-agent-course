"""Calculator agent with a complete multi-step tool-calling loop."""

import inspect

from ollama import chat

import tools
from ollama_setup import ensure_ollama


MODEL = "qwen3.5:9b"
MAX_TOOL_ROUNDS = 10

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

SYSTEM_PROMPT = """
You are a calculator AI agent.

Solve the user's entire mathematical request before returning a final answer.

Rules:
1. Use the available calculator tools whenever arithmetic is required.
2. Do not calculate or guess arithmetic results yourself.
3. Call as many tools, across as many rounds, as the problem requires.
4. Use earlier tool results as inputs to later tool calls when needed.
5. Do not ask for another prompt while any requested calculation is unfinished.
6. When all calculations are complete, explain the final answer clearly.
7. Prefer the most specific tool for the request over chaining basic tools:
   - "X% of Y"                          -> percentage
   - "price after X% discount on Y"     -> discounted_price
   - "GST on X at Y%"                   -> gst
   - "what percentage is X of Y"        -> calculate_percentage_of_total
   - "percentage change from X to Y"    -> calculate_percentage_change
   - "percentage increase/decrease"     -> calculate_percentage_increase_or_decrease
   - "percentage difference between X and Y" -> calculate_percentage_difference
"""


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


def run_agent(user_input: str, messages: list) -> None:
    """Run model/tool rounds until the model produces the final response."""
    messages.append({"role": "user", "content": user_input})

    for _ in range(MAX_TOOL_ROUNDS):
        response = chat(
            model=MODEL,
            messages=messages,
            tools=AVAILABLE_TOOLS,
        )
        messages.append(response.message)

        tool_calls = response.message.tool_calls or []
        if not tool_calls:
            print(f"\nAgent: {response.message.content}")
            return

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

    print(
        f"\nAgent: Stopped after {MAX_TOOL_ROUNDS} tool rounds to prevent "
        "an accidental infinite loop."
    )


def main() -> None:
    """Run the interactive calculator while preserving conversation history."""
    ensure_ollama(MODEL)
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]

    while True:
        user_input = input("\nYou: ").strip()

        if user_input.lower() in {"exit", "quit"}:
            print("Exiting the calculator agent. Goodbye!")
            return

        if not user_input:
            continue

        run_agent(user_input, messages)


if __name__ == "__main__":
    main()
