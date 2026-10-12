from ollama import chat

from config import MODEL, SYSTEM_PROMPT

from note_tools import (
    save_note,
    search_notes,
    list_notes,
    delete_note
)

from file_tools import (
    list_files,
    read_file,
    get_file_info
)

TOOLS = [
    save_note,
    list_notes,
    search_notes,
    delete_note,
    list_files,
    read_file,
    get_file_info,
]

TOOL_REGISTRY = {
    "save_note": save_note,
    "list_notes": list_notes,
    "search_notes": search_notes,
    "delete_note": delete_note,
    "list_files": list_files,
    "read_file": read_file,
    "get_file_info": get_file_info,
}

def run_agent(messages):
    while True:
        response = chat(
            model=MODEL,
            messages=messages,
            tools=TOOLS,
        )
        messages.append(response.message)

        if not response.message.tool_calls:
            return response.message.content

        for tool_call in response.message.tool_calls:
            function_name = tool_call.function.name
            arguments = tool_call.function.arguments

            print(f"Calling tool: {function_name} with arguments: {arguments}")

            function = TOOL_REGISTRY.get(function_name)

            if function is None:
                tool_response = f"Error: Tool '{function_name}' not found."
            else:
                try:
                    result = function(**arguments)
                except Exception as error:
                    result = f"Error executing tool '{function_name}': {str(error)}"
            
            print(f"Tool response: {result}")

            messages.append({
                "role": "tool",
                "tool_name": function_name,
                "content": result
            })