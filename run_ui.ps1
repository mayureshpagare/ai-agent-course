# Start the agent chat UI. Your phone can use it too (same Wi-Fi): scan the QR code
# printed at startup, or click "Use on your phone" in the sidebar.
#   .\run_ui.ps1             dev mode: backend + Vite with hot reload, phone uses port 5173
#   .\run_ui.ps1 -Prod       build the frontend once and serve everything from port 8000
#   .\run_ui.ps1 -LocalOnly  either mode, but only reachable from this computer
#   .\run_ui.ps1 -Remote     same as -Prod (kept for old habits)
# See agent-ui/backend/remote.py for how phones sign in.
param([switch]$Prod, [switch]$Remote, [switch]$LocalOnly, [int]$Port = 8000)

$root = $PSScriptRoot
$backend = Join-Path $root "agent-ui\backend"
$frontend = Join-Path $root "agent-ui\frontend"
$python = Join-Path $backend ".venv\Scripts\python.exe"
$devPort = 5173
$Prod = $Prod -or $Remote

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

# The port phones connect to: Vite's in dev mode, the backend's in -Prod mode.
$publicPort = if ($Prod) { $Port } else { $devPort }

function Test-FirewallOpen([int]$p) {
    $rules = Get-NetFirewallRule -Direction Inbound -Action Allow -Enabled True -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "Agent UI*" }
    foreach ($rule in $rules) {
        $ports = ($rule | Get-NetFirewallPortFilter).LocalPort
        if ($ports -contains "$p" -or $ports -contains "Any") { return $true }
    }
    return $false
}

if (-not $LocalOnly) {
    $env:AGENT_UI_REMOTE = "1"
    $env:AGENT_UI_PORT = "$publicPort"
    if (-not (Test-FirewallOpen $publicPort)) {
        # Windows blocks incoming connections by default; adding a rule needs admin rights once.
        $rule = "New-NetFirewallRule -DisplayName 'Agent UI ($publicPort)' -Direction Inbound -Protocol TCP " +
                "-LocalPort $publicPort -Action Allow -Profile Private"
        Write-Host "Allowing port $publicPort through Windows Firewall so your phone can connect (approve the admin prompt)..."
        try {
            Start-Process powershell -Verb RunAs -Wait -WindowStyle Hidden -ArgumentList "-NoProfile", "-Command", $rule
        } catch {
            Write-Host "Skipped. Your phone can't connect until you run this in an admin PowerShell:"
            Write-Host "  $rule"
        }
    }
}

try {
    if ($Prod) {
        Push-Location $frontend; npm run build; Pop-Location
        $hostAddress = if ($LocalOnly) { "127.0.0.1" } else { "0.0.0.0" }
        Write-Host "Open http://localhost:$Port"
        Push-Location $backend
        try {
            & $python -m uvicorn app:app --host $hostAddress --port $Port
        } finally {
            Pop-Location
        }
    } else {
        # The backend stays private to this computer; phones reach it through Vite's proxy.
        # --reload restarts the backend whenever its .py files change.
        $server = Start-Process -FilePath $python -ArgumentList "-m", "uvicorn", "app:app", "--port", "8000", "--reload" `
            -WorkingDirectory $backend -NoNewWindow -PassThru
        try {
            Write-Host "Open http://localhost:$devPort"
            # vite.config.ts listens on the network when AGENT_UI_REMOTE is set.
            Push-Location $frontend; npm run dev; Pop-Location
        } finally {
            # Kill the whole tree: with --reload the server runs in a child process.
            taskkill /PID $server.Id /T /F 2>$null | Out-Null
        }
    }
} finally {
    Remove-Item Env:AGENT_UI_REMOTE, Env:AGENT_UI_PORT -ErrorAction SilentlyContinue
}
