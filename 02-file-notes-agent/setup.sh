#!/usr/bin/env bash
# One-shot setup: installs Ollama, downloads the model, and installs Python deps.
# Works on Linux, macOS, and Windows (run from Git Bash).
#
#   ./setup.sh                 # uses the default model
#   MODEL=llama3.2 ./setup.sh  # override the model

set -euo pipefail

MODEL="${MODEL:-qwen3.5:9b}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
fail() { printf '\n\033[1;31mError: %s\033[0m\n' "$*" >&2; exit 1; }

case "$(uname -s)" in
    Linux*)               OS=linux ;;
    Darwin*)              OS=mac ;;
    MINGW*|MSYS*|CYGWIN*) OS=windows ;;
    *) fail "Unsupported OS: $(uname -s)" ;;
esac

# On Windows the installer puts ollama here, which may not be on PATH until a new shell.
if [ "$OS" = windows ]; then
    export PATH="$PATH:$(cygpath -u "${LOCALAPPDATA:-$HOME/AppData/Local}")/Programs/Ollama"
fi

# ---------------------------------------------------------------- 1. Ollama
if command -v ollama >/dev/null 2>&1; then
    info "Ollama already installed ($(ollama --version 2>/dev/null | tail -n1))"
else
    info "Installing Ollama..."
    case "$OS" in
        linux)
            curl -fsSL https://ollama.com/install.sh | sh
            ;;
        mac)
            command -v brew >/dev/null 2>&1 \
                || fail "Homebrew not found. Install it from https://brew.sh or get Ollama from https://ollama.com/download"
            brew install ollama
            ;;
        windows)
            installer="$(mktemp -d)/OllamaSetup.exe"
            curl -fL --progress-bar -o "$installer" https://ollama.com/download/OllamaSetup.exe
            "$installer" //VERYSILENT //NORESTART //SUPPRESSMSGBOXES
            ;;
    esac
    command -v ollama >/dev/null 2>&1 || fail "Ollama installed but not found on PATH. Open a new terminal and re-run."
fi

# ---------------------------------------------------------- 2. Ollama server
server_up() { ollama list >/dev/null 2>&1; }

if ! server_up; then
    info "Starting the Ollama server in the background..."
    nohup ollama serve >/dev/null 2>&1 &
    for _ in $(seq 1 60); do
        server_up && break
        sleep 0.5
    done
    server_up || fail "Ollama server did not start."
fi

# ---------------------------------------------------------------- 3. Model
if ollama list | awk 'NR>1 {print $1}' | grep -qx -e "$MODEL" -e "$MODEL:latest"; then
    info "Model $MODEL already downloaded"
else
    info "Downloading model $MODEL (this can take a while)..."
    ollama pull "$MODEL"
fi

# --------------------------------------------------------- 4. Python deps
if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
    PYTHON="$(command -v python3 || command -v python || true)"
    [ -n "$PYTHON" ] || fail "Python not found. Install Python 3 and re-run."

    info "Setting up Python virtual environment..."
    [ -d "$SCRIPT_DIR/.venv" ] || "$PYTHON" -m venv "$SCRIPT_DIR/.venv"
    if [ -x "$SCRIPT_DIR/.venv/Scripts/python.exe" ]; then
        VENV_PY="$SCRIPT_DIR/.venv/Scripts/python.exe"
    else
        VENV_PY="$SCRIPT_DIR/.venv/bin/python"
    fi
    "$VENV_PY" -m pip install --quiet --upgrade pip
    "$VENV_PY" -m pip install --quiet -r "$SCRIPT_DIR/requirements.txt"
fi

info "Setup complete. Ollama is running and $MODEL is ready."
