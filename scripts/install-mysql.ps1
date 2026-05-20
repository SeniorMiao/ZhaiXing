$ErrorActionPreference = "Stop"
. "$PSScriptRoot\env-paths.ps1"

# MySQL 8.0 Windows ZIP（解压即用，数据目录在 D:\01_Dev\Environment\mysql\data）
$MySqlVersion = "8.0.42"
$ZipName = "mysql-$MySqlVersion-winx64.zip"
$FolderName = "mysql-$MySqlVersion-winx64"
$DownloadUrl = "https://mirrors.tuna.tsinghua.edu.cn/mysql/downloads/MySQL-8.0/$MySqlVersion/$ZipName"
$ZipPath = Join-Path $env:TEMP $ZipName

function Ensure-Dir([string]$path) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

$mysqld = Get-MySqlExe "mysqld.exe"
if ($mysqld -and (Test-Path $mysqld)) {
    Write-Host "MySQL 已存在: $(Get-MySqlBinDir)"
    exit 0
}

Ensure-Dir $DevEnvRoot
Ensure-Dir $MySqlRoot

Write-Host "下载 MySQL $MySqlVersion（清华镜像）..."
try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing
}
catch {
    Write-Host "镜像下载失败，尝试官方 CDN ..."
    $DownloadUrl = "https://cdn.mysql.com/Downloads/MySQL-8.0/$ZipName"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing
}

Write-Host "解压到 $MySqlRoot ..."
$staging = Join-Path $env:TEMP "mysql-staging-$MySqlVersion"
if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
Expand-Archive -Path $ZipPath -DestinationPath $staging -Force

$inner = Join-Path $staging $FolderName
if (-not (Test-Path $inner)) {
    $inner = Get-ChildItem -Path $staging -Directory | Select-Object -First 1
    $inner = $inner.FullName
}

$target = Join-Path $MySqlRoot $FolderName
if (Test-Path $target) { Remove-Item -Recurse -Force $target }
Move-Item -Path $inner -Destination $target
Remove-Item -Recurse -Force $staging, $ZipPath -ErrorAction SilentlyContinue

$FolderName | Set-Content -Path $MySqlInstallMarker -Encoding UTF8 -NoNewline

$basedir = $target.Replace("\", "/")
Ensure-Dir $MySqlData

@"
[mysqld]
basedir=$basedir
datadir=$($MySqlData.Replace('\', '/'))
port=$MySqlPort
character-set-server=utf8mb4
collation-server=utf8mb4_0900_ai_ci
default_authentication_plugin=mysql_native_password

[client]
port=$MySqlPort
default-character-set=utf8mb4
"@ | Set-Content -Path $MySqlIni -Encoding UTF8

$mysqld = Get-MySqlExe "mysqld.exe"
if (-not (Test-Path (Join-Path $MySqlData "mysql"))) {
    Write-Host "初始化数据目录 $MySqlData ..."
    & $mysqld --defaults-file=$MySqlIni --initialize-insecure --console
    if ($LASTEXITCODE -ne 0) {
        throw "mysqld --initialize-insecure 失败 (exit $LASTEXITCODE)"
    }
}

Write-Host "MySQL 安装完成。"
Write-Host "  程序: $target"
Write-Host "  数据: $MySqlData"
Write-Host "  配置: $MySqlIni"
Write-Host "启动并创建账号: powershell -File `"$PSScriptRoot\start-mysql.ps1`" -InitAccounts"
