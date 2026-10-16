import json

from ollama import chat

from config import MODEL

from note_tools import (
    save_note,
    search_notes,
    list_notes,
    get_notes_by_category,
    delete_note,
    delete_all_notes,
)

from file_tools import (
    list_files,
    find_files,
    read_file,
    get_file_info
)

TOOLS = [
    save_note,
    list_notes,
    search_notes,
    get_notes_by_category,
    delete_note,
    delete_all_notes,
    list_files,
    find_files,
    read_file,
    get_file_info,
]

TOOL_REGISTRY = {
    "save_note": save_note,
    "list_notes": list_notes,
    "search_notes": search_notes,
    "get_notes_by_category": get_notes_by_category,
    "delete_note": delete_note,
    "delete_all_notes": delete_all_notes,
    "list_files": list_files,
    "find_files": find_files,
    "read_file": read_file,
    "get_file_info": get_file_info,
}

# Tools that need a "yes" from the human before they run. The check lives
# here in Python, not in the prompt, so the model cannot talk its way past it.
CONFIRMATION_REQUIRED = {
    "delete_all_notes": "This will permanently delete ALL saved notes.",
}

def confirm_tool_call(function_name):
    """Ask the user to approve a dangerous tool call. Returns True if approved."""
    warning = CONFIRMATION_REQUIRED[function_name]
    answer = input(f"[Approval needed] {warning} Type 'yes' to continue: ")
    return answer.strip().lower() == "yes"

def to_tool_content(result):
    """Tool messages carry text, so structured results are sent as JSON."""
    if isinstance(result, str):
        return result
    return json.dumps(result, default=str)

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
                result = {"error": f"Tool '{function_name}' not found."}
            elif function_name in CONFIRMATION_REQUIRED and not confirm_tool_call(function_name):
                result = {
                    "status": "cancelled",
                    "message": "The user did not approve this action. Nothing was changed.",
                }
            else:
                try:
                    result = function(**arguments)
                except Exception as error:
                    result = {"error": f"Error executing tool '{function_name}': {error}"}

            content = to_tool_content(result)
            print(f"Tool response: {content}")

            messages.append({
                "role": "tool",
                "tool_name": function_name,
                "content": content
            })
