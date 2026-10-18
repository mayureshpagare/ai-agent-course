"""Generic agent loop that runs INSIDE an agent's own virtualenv.

Started by the backend as:  <agent>/.venv/Scripts/python.exe worker.py --agent-dir <agent>

Protocol: one JSON object per line.
  stdin  <- {"type": "chat", "messages": [...]}
            {"type": "approval", "call_id": "...", "approved": true}
  stdout -> {"type": "ready" | "fatal" | "tool_call" | "tool_result"
                    | "approval_required" | "final" | "error", ...}

Only the standard library and `ollama` are used, because every agent venv has those.
"""

import argparse
import importlib
import json
import os
import sys
import traceback
import uuid

MAX_TOOL_ROUNDS = 10


def open_protocol_channel():
    """Keep the real stdout for protocol messages and send everything else to stderr.

    Tools (and subprocesses such as `ollama pull`) print freely; redirecting at the
    file-descriptor level stops that output from corrupting the JSON stream.
    """
    protocol_fd = os.dup(1)
    os.dup2(2, 1)
    sys.stdout = sys.stderr
    return os.fdopen(protocol_fd, "w", encoding="utf-8", buffering=1)


PROTOCOL = open_protocol_channel()


def emit(event_type, **data):
    PROTOCOL.write(json.dumps({"type": event_type, **data}, default=str) + "\n")
    PROTOCOL.flush()


def read_command():
    line = sys.stdin.readline()
    if not line:
        sys.exit(0)  # backend closed the pipe
    return json.loads(line)


def to_tool_content(result):
    """Tool messages carry text, so structured results are sent as JSON."""
    if isinstance(result, str):
        return result
    return json.dumps(result, default=str)


def wait_for_approval(call_id):
    while True:
        command = read_command()
        if command.get("type") == "approval" and command.get("call_id") == call_id:
            return bool(command.get("approved"))


def run_chat(entry, messages):
    from ollama import chat

    tools = list(entry.TOOLS)
    registry = {tool.__name__: tool for tool in tools}
    confirmations = getattr(entry, "CONFIRMATION_REQUIRED", {}) or {}
    new_messages = []

    for _ in range(MAX_TOOL_ROUNDS):
        response = chat(model=entry.MODEL, messages=messages, tools=tools)
        message = response.message.model_dump(exclude_none=True)
        messages.append(message)
        new_messages.append(message)

        tool_calls = response.message.tool_calls or []
        if not tool_calls:
            emit("final", content=response.message.content or "", new_messages=new_messages)
            return

        for tool_call in tool_calls:
            name = tool_call.function.name
            arguments = dict(tool_call.function.arguments or {})
            call_id = uuid.uuid4().hex[:12]
            emit("tool_call", call_id=call_id, name=name, args=arguments)

            function = registry.get(name)
            if function is None:
                result = {"error": f"Tool '{name}' not found."}
            elif name in confirmations:
                emit("approval_required", call_id=call_id, name=name,
                     args=arguments, warning=confirmations[name])
                if wait_for_approval(call_id):
                    result = call_tool(function, name, arguments)
                else:
                    result = {
                        "status": "cancelled",
                        "message": "The user did not approve this action. Nothing was changed.",
                    }
            else:
                result = call_tool(function, name, arguments)

            content = to_tool_content(result)
            emit("tool_result", call_id=call_id, name=name, content=content)
            tool_message = {"role": "tool", "tool_name": name, "content": content}
            messages.append(tool_message)
            new_messages.append(tool_message)

    stopped = {
        "role": "assistant",
        "content": f"Stopped after {MAX_TOOL_ROUNDS} tool rounds to prevent an infinite loop.",
    }
    new_messages.append(stopped)
    emit("final", content=stopped["content"], new_messages=new_messages)


def call_tool(function, name, arguments):
    try:
        return function(**arguments)
    except Exception as error:
        return {"error": f"Error executing tool '{name}': {error}"}


def load_agent(agent_dir):
    os.chdir(agent_dir)
    sys.path.insert(0, agent_dir)
    entry = importlib.import_module("ui_entry")

    try:
        from ollama_setup import ensure_ollama
    except ImportError:
        ensure_ollama = None
    if ensure_ollama is not None:
        ensure_ollama(entry.MODEL)

    setup = getattr(entry, "setup", None)
    if callable(setup):
        setup()
    return entry


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--agent-dir", required=True)
    agent_dir = os.path.abspath(parser.parse_args().agent_dir)

    try:
        entry = load_agent(agent_dir)
    except BaseException as error:  # includes sys.exit() from ensure_ollama
        emit("fatal", message=f"Could not start agent: {error}", detail=traceback.format_exc())
        return
    emit("ready")

    while True:
        command = read_command()
        if command.get("type") != "chat":
            continue
        try:
            # The system prompt is added here, not stored, so prompt edits apply to old chats.
            messages = [{"role": "system", "content": entry.SYSTEM_PROMPT}, *command["messages"]]
            run_chat(entry, messages)
        except Exception as error:
            traceback.print_exc()
            emit("error", message=str(error))


if __name__ == "__main__":
    main()
