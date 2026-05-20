$ErrorActionPreference = "Stop"
. "$PSScriptRoot\env-paths.ps1"

function Get-PythonPath([string]$repoRoot) {
    if (Test-Path $VenvPython) { return $VenvPython }
    $py = Join-Path $repoRoot "ZX\Scripts\python.exe"
    if (-not (Test-Path $py)) {
        throw "找不到 Python 虚拟环境。请在项目根执行: python -m venv ZX 或使用 $VenvRoot"
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
Write-Host "从任意目录启动本脚本示例:"
Write-Host ("  powershell -ExecutionPolicy Bypass -File `"" + (Join-Path $repoRoot "scripts\start-dev.ps1") + "`"")
Write-Host ("  或: powershell -ExecutionPolicy Bypass -File `"" + (Join-Path $repoRoot "start-dev.ps1") + "`"")
Write-Host ""

$apiArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-Command", ("cd ""{0}""; & ""{1}"" -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload" -f $repoRoot, $py)
)
Start-Process -FilePath "powershell.exe" -ArgumentList $apiArgs -WindowStyle Normal | Out-Null

$workerCmd = @"
`$env:OMP_NUM_THREADS='1'; `$env:MKL_NUM_THREADS='1'; `$env:OPENBLAS_NUM_THREADS='1'
cd ""$repoRoot""
& ""$py"" -m celery -A backend.app.worker.celery_app worker -l info -P solo --concurrency=1
"@

$workerArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-Command", $workerCmd
)
Start-Process -FilePath "powershell.exe" -ArgumentList $workerArgs -WindowStyle Normal | Out-Null

Write-Host "Started API (uvicorn) and worker (celery) in two new windows."
Write-Host "Stop them with Ctrl+C in each window."
Write-Host ""
