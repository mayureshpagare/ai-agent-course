"""One long-lived worker subprocess per agent, spoken to with JSON lines.

Plain subprocess + a reader thread is used instead of asyncio subprocesses,
because those are not supported by every event loop on Windows.
"""

import asyncio
import json
import subprocess
import threading
from pathlib import Path

from registry import AgentInfo

WORKER_SCRIPT = Path(__file__).with_name("worker.py")


class WorkerError(Exception):
    pass


class AgentWorker:
    def __init__(self, agent: AgentInfo):
        self.agent = agent
        self.process: subprocess.Popen | None = None
        self.events: asyncio.Queue | None = None
        self.lock = asyncio.Lock()  # one chat turn at a time per agent

    @property
    def alive(self) -> bool:
        return self.process is not None and self.process.poll() is None

    async def ensure_started(self) -> None:
        if self.alive:
            return
        loop = asyncio.get_running_loop()
        self.events = asyncio.Queue()
        self.process = subprocess.Popen(
            [self.agent.python, "-u", str(WORKER_SCRIPT), "--agent-dir", str(self.agent.path)],
            cwd=self.agent.path,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=None,  # tool prints / tracebacks show up in the backend console
            text=True,
            encoding="utf-8",
            bufsize=1,
        )
        threading.Thread(target=self._read_stdout, args=(self.process, self.events, loop),
                         daemon=True).start()

        first = await self.events.get()
        if first["type"] != "ready":
            self.kill()
            raise WorkerError(first.get("message", "Agent failed to start."))

    @staticmethod
    def _read_stdout(process, queue, loop):
        for line in process.stdout:
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            loop.call_soon_threadsafe(queue.put_nowait, event)
        loop.call_soon_threadsafe(queue.put_nowait, {
            "type": "fatal", "message": "The agent process exited unexpectedly."})

    def send(self, command: dict) -> None:
        if not self.alive:
            raise WorkerError("Agent is not running.")
        self.process.stdin.write(json.dumps(command) + "\n")
        self.process.stdin.flush()

    async def next_event(self) -> dict:
        return await self.events.get()

    def kill(self) -> None:
        if self.process is not None and self.process.poll() is None:
            self.process.kill()
        self.process = None


class WorkerPool:
    def __init__(self):
        self.workers: dict[str, AgentWorker] = {}

    def get(self, agent: AgentInfo) -> AgentWorker:
        worker = self.workers.get(agent.id)
        if worker is None:
            worker = self.workers[agent.id] = AgentWorker(agent)
        return worker

    def shutdown(self) -> None:
        for worker in self.workers.values():
            worker.kill()
