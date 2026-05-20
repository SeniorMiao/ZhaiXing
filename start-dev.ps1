# 项目根目录启动入口（任意当前目录下可双击或在 PowerShell 中执行）
$ErrorActionPreference = "Stop"
$launcher = Join-Path $PSScriptRoot "scripts\start-dev.ps1"
if (-not (Test-Path $launcher)) {
    throw "找不到脚本: $launcher"
}
& $launcher
