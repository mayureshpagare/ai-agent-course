# Agent UI

This is a chat interface in the style of ChatGPT or Claude for every agent in this repo. You pick an agent in the sidebar and chat with it. While the agent works, its tool calls show up as live cards. You approve dangerous tools with a button click. Chats are saved locally.

## Run

From the repo root:

```powershell
.\run_ui.ps1             # dev mode: http://localhost:5173 (hot reload)
.\run_ui.ps1 -Prod       # build once and serve everything from http://localhost:8000 (optional: -Port 8080)
.\run_ui.ps1 -LocalOnly  # either mode, but not reachable from other devices
```

The first run creates `agent-ui/backend/.venv` and installs the npm packages. Ollama must be installed, and each agent's own `.venv` must exist, just as it does for running `main.py`.

## Use it from your phone

Phone access is on in both modes unless you pass `-LocalOnly`. At startup the terminal prints a sign-in link and a QR code. You can also click **Use on your phone** at the bottom of the sidebar on the computer to show the same QR code. Phones use port 5173 in dev mode and port 8000 with `-Prod`.

1. Connect your phone to the same Wi-Fi as the computer.
2. Scan the QR code with the phone's camera. This signs the phone in for a year and opens the chat.
3. Optional: in the browser menu, choose **Add to Home Screen** (Safari: Share → Add to Home Screen) to open it full-screen like an app.

Security:
- Phones must sign in with a random access token, which is stored in `backend/data/remote_token.txt`. To sign out every phone, delete that file and restart.
- The browser on the computer itself never needs the token.
- Traffic is plain HTTP, so only use this on networks you trust.
- To use it **away from home**, install [Tailscale](https://tailscale.com) on the computer and the phone. The computer's `100.x.y.z` Tailscale address then works from anywhere, and the connection is encrypted. Don't port-forward 8000 on your router.

The first time you use a port, the launcher asks for admin rights once, to allow that port through Windows Firewall (for Private networks only). If you decline, it prints the `New-NetFirewallRule` command to run yourself. If the phone still can't connect, check that your Wi-Fi is set to **Private** in Windows network settings.

## Native mobile app

[mobile/](mobile) has a Flutter app for Android and iOS that does everything the web app does, with a phone-first layout. It uses the same backend with no changes. Pair it by scanning the same QR code, or by typing the address and pasting the token. Setup, tests and troubleshooting are in [mobile/README.md](mobile/README.md).

## How it works

```
React (Vite)  ──HTTP/SSE──▶  FastAPI backend (agent-ui/backend)
                                 │  one subprocess per agent, JSON lines over stdin/stdout
                                 ▼
                 <agent>/.venv python  worker.py  (cwd = agent folder)
                                 │  imports ui_entry.py → TOOLS, MODEL, SYSTEM_PROMPT
                                 ▼
                              Ollama
```

- Each agent runs with **its own venv**, with the agent folder as the working directory. Because of that, `data/...` paths and dependencies such as pandas work exactly as they do with `main.py`.
- `worker.py` contains one generic tool-calling loop. It stops after at most 10 rounds, and it pauses for an Approve/Deny decision on the tools listed in `CONFIRMATION_REQUIRED`.
- Chat history is stored in `agent-ui/backend/data/history.db` (SQLite). The system prompt is not stored, so when you edit a prompt the change also applies to old chats.
- The `main.py` CLIs are unchanged and still work.

## Adding a new agent

1. Create the agent folder at the repo root, for example `04-my-agent/`, with its tools, `.venv`, and so on.
2. Copy [templates/ui_entry.py](templates/ui_entry.py) into that folder and fill in `NAME`, `DESCRIPTION`, `TOOLS`, `MODEL` and `SYSTEM_PROMPT`.
3. Optional: add a logo as `agent-ui/logos/04-my-agent.svg` (or `.png`/`.webp`). See [logos/README.md](logos/README.md) for the recommended format.
4. Refresh the browser. The new agent appears in the sidebar.
