"""FastAPI backend for the agent chat UI.

Run from agent-ui/backend:  .venv\\Scripts\\python -m uvicorn app:app --port 8000
"""

import json
from collections import deque
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

import history
from registry import discover_agents
from workers import AgentWorker, WorkerError, WorkerPool

FRONTEND_DIST = Path(__file__).resolve().parents[1] / "frontend" / "dist"
TITLE_LENGTH = 50

pool = WorkerPool()
active_turns: dict[str, AgentWorker] = {}  # conversation_id -> worker running its turn
stopped_turns: set[str] = set()


@asynccontextmanager
async def lifespan(_app):
    yield
    pool.shutdown()


app = FastAPI(title="Agent UI", lifespan=lifespan)


class NewConversation(BaseModel):
    agent_id: str


class Rename(BaseModel):
    title: str


class UserMessage(BaseModel):
    content: str


class Approval(BaseModel):
    call_id: str
    approved: bool


def get_agent(agent_id: str):
    agent = discover_agents().get(agent_id)
    if agent is None:
        raise HTTPException(404, f"Unknown agent '{agent_id}'")
    return agent


def get_conversation_or_404(conversation_id: str) -> dict:
    conversation = history.get_conversation(conversation_id)
    if conversation is None:
        raise HTTPException(404, "Conversation not found")
    return conversation


def to_display(messages: list[dict]) -> list[dict]:
    """Turn raw model messages into chat items: user / assistant / tool cards."""
    items, waiting_for_result = [], deque()
    for index, message in enumerate(messages):
        role = message.get("role")
        if role == "user":
            items.append({"kind": "user", "content": message.get("content", "")})
        elif role == "assistant":
            if (message.get("thinking") or "").strip():
                items.append({"kind": "thinking", "content": message["thinking"]})
            if (message.get("content") or "").strip():
                # Text written alongside tool calls is intermediate reasoning, not the answer.
                kind = "thinking" if message.get("tool_calls") else "assistant"
                items.append({"kind": kind, "content": message["content"]})
            for n, call in enumerate(message.get("tool_calls") or []):
                function = call.get("function", {})
                card = {"kind": "tool", "id": f"h{index}-{n}", "name": function.get("name"),
                        "args": function.get("arguments", {}), "result": None, "status": "done"}
                items.append(card)
                waiting_for_result.append(card)
        elif role == "tool" and waiting_for_result:
            waiting_for_result.popleft()["result"] = message.get("content", "")
    return items


@app.get("/api/agents")
def list_agents():
    return [agent.to_json() for agent in discover_agents().values()]


@app.get("/api/conversations")
def list_conversations(agent_id: str | None = None):
    return history.list_conversations(agent_id)


@app.post("/api/conversations")
def create_conversation(body: NewConversation):
    get_agent(body.agent_id)
    return history.create_conversation(body.agent_id)


@app.get("/api/conversations/{conversation_id}")
def get_conversation(conversation_id: str):
    conversation = get_conversation_or_404(conversation_id)
    return {**conversation, "items": to_display(history.get_messages(conversation_id))}


@app.patch("/api/conversations/{conversation_id}")
def rename_conversation(conversation_id: str, body: Rename):
    get_conversation_or_404(conversation_id)
    history.rename_conversation(conversation_id, body.title.strip() or "Untitled")
    return {"ok": True}


@app.delete("/api/conversations/{conversation_id}")
def delete_conversation(conversation_id: str):
    history.delete_conversation(conversation_id)
    return {"ok": True}


@app.post("/api/conversations/{conversation_id}/approve")
def approve(conversation_id: str, body: Approval):
    worker = active_turns.get(conversation_id)
    if worker is None:
        raise HTTPException(409, "No running turn is waiting for approval.")
    worker.send({"type": "approval", "call_id": body.call_id, "approved": body.approved})
    return {"ok": True}


@app.post("/api/conversations/{conversation_id}/stop")
def stop(conversation_id: str):
    worker = active_turns.get(conversation_id)
    if worker is not None:
        stopped_turns.add(conversation_id)
        worker.kill()  # restarted automatically on the next message
    return {"ok": True}


def sse(event: dict) -> str:
    return f"data: {json.dumps(event)}\n\n"


@app.post("/api/conversations/{conversation_id}/messages")
async def send_message(conversation_id: str, body: UserMessage):
    conversation = get_conversation_or_404(conversation_id)
    agent = get_agent(conversation["agent_id"])
    worker = pool.get(agent)
    content = body.content.strip()
    if not content:
        raise HTTPException(400, "Message is empty.")

    async def stream():
        async with worker.lock:
            yield sse({"type": "status", "message": f"Starting {agent.name}..."}
                      if not worker.alive else {"type": "status", "message": "Thinking..."})
            try:
                await worker.ensure_started()
            except WorkerError as error:
                yield sse({"type": "error", "message": str(error)})
                return

            prior = history.get_messages(conversation_id)
            user_message = {"role": "user", "content": content}
            history.add_messages(conversation_id, [user_message])
            if not prior and conversation["title"] == "New chat":
                title = content if len(content) <= TITLE_LENGTH else content[:TITLE_LENGTH] + "…"
                history.rename_conversation(conversation_id, title)
                yield sse({"type": "title", "title": title})

            active_turns[conversation_id] = worker
            finished = False
            try:
                worker.send({"type": "chat", "messages": [*prior, user_message]})
                yield sse({"type": "status", "message": "Thinking..."})
                while True:
                    event = await worker.next_event()
                    kind = event.get("type")
                    if kind == "final":
                        history.add_messages(conversation_id, event.pop("new_messages", []))
                        finished = True
                        yield sse(event)
                        return
                    if kind in ("error", "fatal"):
                        finished = True
                        if kind == "fatal":
                            worker.kill()
                        message = ("Stopped." if conversation_id in stopped_turns
                                   else event.get("message", "Agent error."))
                        yield sse({"type": "error", "message": message})
                        return
                    yield sse(event)
            finally:
                active_turns.pop(conversation_id, None)
                stopped_turns.discard(conversation_id)
                if not finished:  # client went away mid-turn
                    worker.kill()

    return StreamingResponse(stream(), media_type="text/event-stream",
                             headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})


if FRONTEND_DIST.exists():
    app.mount("/", StaticFiles(directory=FRONTEND_DIST, html=True), name="frontend")
