$ErrorActionPreference = "Stop"
. "$PSScriptRoot\env-paths.ps1"

# Windows 版 Redis（tporadowski，兼容 Redis 5，满足 Celery broker）
$RedisVersion = "5.0.14.1"
$ZipName = "Redis-x64-$RedisVersion.zip"
$DownloadUrls = @(
    "https://github.com/tporadowski/redis/releases/download/v$RedisVersion/$ZipName",
    "https://ghfast.top/https://github.com/tporadowski/redis/releases/download/v$RedisVersion/$ZipName",
    "https://mirror.ghproxy.com/https://github.com/tporadowski/redis/releases/download/v$RedisVersion/$ZipName"
)
$ZipPath = Join-Path $env:TEMP $ZipName

function Save-RemoteZip([string[]]$urls, [string]$outFile) {
    foreach ($url in $urls) {
        Write-Host "尝试下载: $url"
        try {
            Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing -TimeoutSec 120
            if ((Get-Item $outFile).Length -gt 1MB) { return }
        }
        catch {
            Write-Warning $_.Exception.Message
        }
    }
    throw "所有下载源均失败，请手动下载 $ZipName 解压到 $RedisRoot"
}

function Ensure-Dir([string]$path) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

if (Test-Path $RedisExe) {
    Write-Host "Redis 已存在: $RedisRoot"
    exit 0
}

Ensure-Dir $DevEnvRoot
Ensure-Dir $RedisRoot

if (-not (Test-Path $ZipPath) -or (Get-Item $ZipPath).Length -lt 1MB) {
    Write-Host "下载 Redis $RedisVersion ..."
    Save-RemoteZip -urls $DownloadUrls -outFile $ZipPath
}

Write-Host "解压到 $RedisRoot ..."
$staging = Join-Path $env:TEMP "redis-staging-$RedisVersion"
if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
Expand-Archive -Path $ZipPath -DestinationPath $staging -Force

$serverInStaging = Get-ChildItem -Path $staging -Filter "redis-server.exe" -Recurse -File | Select-Object -First 1
if (-not $serverInStaging) {
    throw "解压包中未找到 redis-server.exe"
}
$sourceDir = $serverInStaging.DirectoryName
Copy-Item -Path (Join-Path $sourceDir "*") -Destination $RedisRoot -Recurse -Force
Remove-Item -Recurse -Force $staging, $ZipPath -ErrorAction SilentlyContinue

Ensure-Dir $RedisData

if (-not (Test-Path $RedisConf)) {
    @"
bind 127.0.0.1
port $RedisPort
dir ./data
appendonly yes
"@ | Set-Content -Path $RedisConf -Encoding UTF8
}

Write-Host "Redis 安装完成: $RedisRoot"
Write-Host "启动: powershell -File `"$PSScriptRoot\start-redis.ps1`""
