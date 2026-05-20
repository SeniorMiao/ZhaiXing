$ErrorActionPreference = "Stop"
. "$PSScriptRoot\env-paths.ps1"

. "$PSScriptRoot\env-paths.ps1"
$repoRoot = Get-RepoRoot

Write-Host ""
Write-Host "开发环境根目录: $DevEnvRoot"
Write-Host "  Redis: $RedisRoot"
Write-Host "  MySQL: $MySqlRoot (data: $MySqlData)"
Write-Host ""

if (-not (Test-Path $RedisExe)) {
    Write-Host ">>> 安装 Redis ..."
    & "$PSScriptRoot\install-redis.ps1"
}

if (-not (Get-MySqlExe "mysqld.exe")) {
    Write-Host ">>> 安装 MySQL（体积较大，请耐心等待）..."
    & "$PSScriptRoot\install-mysql.ps1"
}

Write-Host ">>> 启动 Redis ..."
& "$PSScriptRoot\start-redis.ps1"

Write-Host ">>> 启动 MySQL ..."
& "$PSScriptRoot\start-mysql.ps1" -InitAccounts

Write-Host ""
Write-Host "依赖已就绪。在项目根目录执行："
Write-Host "  cd $repoRoot"
if (Test-Path $VenvPython) {
    Write-Host "  & `"$VenvPython`" -m backend.app.scripts.init_db"
}
else {
    Write-Host "  .\ZX\Scripts\python -m backend.app.scripts.init_db"
}
Write-Host ""
