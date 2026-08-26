"""Calculator agent with a complete multi-step tool-calling loop."""

from ollama import chat

from tools import add, divide, multiply, percentage, power, subtract


MODEL = "qwen3.5:9b"
MAX_TOOL_ROUNDS = 10

AVAILABLE_TOOLS = [add, subtract, multiply, divide, power, percentage]
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
