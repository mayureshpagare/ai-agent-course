# Start the agent chat UI.
#   .\run_ui.ps1          dev mode: backend on :8000 + Vite on :5173 (hot reload)
#   .\run_ui.ps1 -Prod    build the frontend once and serve everything from :8000
#   .\run_ui.ps1 -Remote  like -Prod, but reachable from your phone on the same network
#                         (prints a QR code to sign in; see agent-ui/backend/remote.py)
param([switch]$Prod, [switch]$Remote, [int]$Port = 8000)

$root = $PSScriptRoot
$backend = Join-Path $root "agent-ui\backend"
$frontend = Join-Path $root "agent-ui\frontend"
$python = Join-Path $backend ".venv\Scripts\python.exe"

if (-not (Test-Path $python)) {
    Write-Host "Creating backend virtualenv..."
    python -m venv (Join-Path $backend ".venv")
    & $python -m pip install -r (Join-Path $backend "requirements.txt")
}
if (-not (Test-Path (Join-Path $frontend "node_modules"))) {
    Write-Host "Installing frontend packages..."
    Push-Location $frontend; npm install; Pop-Location
}

# Pick up packages added to requirements.txt since the venv was created.
& $python -m pip install -q -r (Join-Path $backend "requirements.txt")

if ($Prod -or $Remote) {
    Push-Location $frontend; npm run build; Pop-Location
    $hostAddress = "127.0.0.1"
    if ($Remote) {
        $hostAddress = "0.0.0.0"
        $env:AGENT_UI_REMOTE = "1"
        $env:AGENT_UI_PORT = "$Port"
        Write-Host "If your phone can't connect, allow port $Port through Windows Firewall (admin PowerShell):"
        Write-Host "  New-NetFirewallRule -DisplayName 'Agent UI' -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Profile Private"
    }
    Write-Host "Open http://localhost:$Port"
    Push-Location $backend
    try {
        & $python -m uvicorn app:app --host $hostAddress --port $Port
    } finally {
        Pop-Location
        Remove-Item Env:AGENT_UI_REMOTE, Env:AGENT_UI_PORT -ErrorAction SilentlyContinue
    }
} else {
    # --reload restarts the backend whenever its .py files change.
    $server = Start-Process -FilePath $python -ArgumentList "-m", "uvicorn", "app:app", "--port", "8000", "--reload" `
        -WorkingDirectory $backend -NoNewWindow -PassThru
    try {
        Write-Host "Open http://localhost:5173"
        Push-Location $frontend; npm run dev; Pop-Location
    } finally {
        # Kill the whole tree: with --reload the server runs in a child process.
        taskkill /PID $server.Id /T /F 2>$null | Out-Null
    }
}
