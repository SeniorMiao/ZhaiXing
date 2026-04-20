$ErrorActionPreference = "Stop"

function Get-RepoRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Get-PythonPath([string]$repoRoot) {
  $py = Join-Path $repoRoot "ZX\\Scripts\\python.exe"
  if (-not (Test-Path $py)) {
    throw "Cannot find venv python: $py"
  }
  return $py
}

$repoRoot = Get-RepoRoot
$py = Get-PythonPath $repoRoot

Write-Host ""
Write-Host ("Repo:   " + $repoRoot)
Write-Host ("Python: " + $py)
Write-Host ""
Write-Host "Flutter API_BASE_URL:"
Write-Host "  - Android emulator: http://10.0.2.2:8000"
Write-Host "  - Physical phone:   use ipconfig WLAN IPv4 -> http://<ip>:8000"
Write-Host ""

# Start API in a new window
$apiArgs = @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-Command", ("cd ""{0}""; & ""{1}"" -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload" -f $repoRoot, $py)
)
Start-Process -FilePath "powershell.exe" -ArgumentList $apiArgs -WindowStyle Normal | Out-Null

# Start Celery worker in a new window
$workerArgs = @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-Command", ("cd ""{0}""; & ""{1}"" -m celery -A backend.app.worker.celery_app worker -l info -P solo" -f $repoRoot, $py)
)
Start-Process -FilePath "powershell.exe" -ArgumentList $workerArgs -WindowStyle Normal | Out-Null

Write-Host "Started API (uvicorn) and worker (celery) in two new windows."
Write-Host "Stop them with Ctrl+C in each window."
Write-Host ""

