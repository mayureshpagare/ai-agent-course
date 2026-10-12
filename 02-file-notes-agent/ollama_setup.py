"""Make sure the local Ollama server is running and the model is available."""

import shutil
import subprocess
import sys
import time

import ollama

SERVER_START_TIMEOUT = 30  # seconds


def _server_is_up() -> bool:
    try:
        ollama.list()
        return True
    except (ConnectionError, ollama.ResponseError, OSError):
        return False


def _start_server() -> None:
    """Launch `ollama serve` in the background, detached from this program."""
    if shutil.which("ollama") is None:
        sys.exit("Error: 'ollama' was not found on PATH. Install it from https://ollama.com/")

    print("Ollama server is not running. Starting it in the background...")
    options = {"stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL}
    if sys.platform == "win32":
        options["creationflags"] = (
            subprocess.DETACHED_PROCESS
            | subprocess.CREATE_NEW_PROCESS_GROUP
            | subprocess.CREATE_NO_WINDOW
        )
    else:
        options["start_new_session"] = True
    subprocess.Popen(["ollama", "serve"], **options)

    deadline = time.time() + SERVER_START_TIMEOUT
    while time.time() < deadline:
        if _server_is_up():
            return
        time.sleep(0.5)
    sys.exit(f"Error: Ollama server did not start within {SERVER_START_TIMEOUT} seconds.")


def ensure_ollama(model: str) -> None:
    """Start the Ollama server if needed and pull `model` if it is missing."""
    if not _server_is_up():
        _start_server()

    installed = {m.model for m in ollama.list().models}
    if model not in installed and f"{model}:latest" not in installed:
        print(f"Model '{model}' not found locally. Pulling it (one-time download)...")
        subprocess.run(["ollama", "pull", model], check=True)
