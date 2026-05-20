$ErrorActionPreference = "Stop"
. "$PSScriptRoot\env-paths.ps1"

if (-not (Test-Path $RedisExe)) {
    Write-Host "未安装 Redis，请先执行: install-redis.ps1"
    exit 1
}

$tcp = Test-NetConnection -ComputerName 127.0.0.1 -Port $RedisPort -WarningAction SilentlyContinue
if ($tcp.TcpTestSucceeded) {
    Write-Host "Redis 已在运行 (127.0.0.1:$RedisPort)"
    exit 0
}

if (-not (Test-Path $RedisData)) {
    New-Item -ItemType Directory -Path $RedisData -Force | Out-Null
}

Write-Host "启动 Redis -> $RedisRoot"
Set-Location $RedisRoot
Start-Process -FilePath $RedisExe -ArgumentList $RedisConf -WindowStyle Minimized
Start-Sleep -Seconds 2

$tcp = Test-NetConnection -ComputerName 127.0.0.1 -Port $RedisPort -WarningAction SilentlyContinue
if ($tcp.TcpTestSucceeded) {
    Write-Host "Redis 已监听 127.0.0.1:$RedisPort"
}
else {
    Write-Warning "Redis port $RedisPort not ready yet; wait a few seconds and retry."
}
