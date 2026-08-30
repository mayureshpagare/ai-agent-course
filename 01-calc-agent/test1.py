from ollama import chat

from tools import *

tools = [add, subtract, multiply, divide, power, percentage]

tool_registry = {tool.__name__: tool for tool in tools}

SYSTEM_PROMPT = """
You are a calculator AI agent.

Your job is to solve mathematical problems accurately.

Rules:

1. Use the available calculator tools whenever arithmetic is required.
2. Do not guess calculation results.
3. You may call multiple tools when necessary.
4. Explain the final answer clearly.
"""

MODEL = "qwen3.5:9b"


messages = [
    {
        "role": "system",
        "content": SYSTEM_PROMPT
    }
]

while True:
    user_input = input("You: ")
    if user_input.lower() in ["exit", "quit"]:
        print("Exiting the calculator agent. Goodbye!")
        break
    messages.append({
        "role": "user",
        "content": user_input
    })
    
    response = chat(
        model=MODEL,
        messages=messages,
        tools=tools
    )

    messages.append(response.message)

    if not response.message.tool_calls:

        print("\nAgent:", response.message.content)
        break

    for tool_call in response.message.tool_calls:

        function_name = tool_call.function.name
        arguments = tool_call.function.arguments

        print(f"\n[Tool selected: {function_name}]")
        print(f"[Arguments: {arguments}]")

        function = tool_registry[function_name]

        try:

            result = function(**arguments)

        except Exception as error:

            result = f"Error: {error}"

        print(f"[Tool result: {result}]")

        messages.append(
            {
                "role": "tool",
                "tool_name": function_name,
                "content": str(result)
            }
        )