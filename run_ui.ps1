# Start the agent chat UI.
#   .\run_ui.ps1          dev mode: backend on :8000 + Vite on :5173 (hot reload)
#   .\run_ui.ps1 -Prod    build the frontend once and serve everything from :8000
param([switch]$Prod)

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

if ($Prod) {
    Push-Location $frontend; npm run build; Pop-Location
    Write-Host "Open http://localhost:8000"
    Push-Location $backend
    & $python -m uvicorn app:app --port 8000
    Pop-Location
} else {
    $server = Start-Process -FilePath $python -ArgumentList "-m", "uvicorn", "app:app", "--port", "8000" `
        -WorkingDirectory $backend -NoNewWindow -PassThru
    try {
        Write-Host "Open http://localhost:5173"
        Push-Location $frontend; npm run dev; Pop-Location
    } finally {
        Stop-Process -Id $server.Id -ErrorAction SilentlyContinue
    }
}
