# 本机开发环境根目录（MySQL / Redis / 可选 venv 均在此下）
$script:DevEnvRoot = "D:\01_Dev\Environment"

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

$script:RepoRoot = Get-RepoRoot
$script:MobileRoot = Join-Path $RepoRoot "mobile"

$script:RedisRoot = Join-Path $DevEnvRoot "Redis"
$script:RedisData = Join-Path $RedisRoot "data"
$script:RedisExe  = Join-Path $RedisRoot "redis-server.exe"
$script:RedisConf = Join-Path $RedisRoot "redis.windows.conf"

$script:MySqlRoot = Join-Path $DevEnvRoot "mysql"
$script:MySqlData = Join-Path $MySqlRoot "data"
$script:MySqlIni  = Join-Path $MySqlRoot "my.ini"
# zip 解压后目录名因版本而异，安装脚本会写入 install-dir.txt
$script:MySqlInstallMarker = Join-Path $MySqlRoot "install-dir.txt"

$script:FlutterRoot = Join-Path $DevEnvRoot "FlutterSDK"
$script:FlutterBin = Join-Path $FlutterRoot "bin"
$script:FlutterGitMirror = "https://mirrors.tuna.tsinghua.edu.cn/git/flutter-sdk.git"
# 与项目同盘，避免 Windows 下 Kotlin 编译跨盘符 relative path 失败
$script:PubCacheRoot = Join-Path $DevEnvRoot "PubCache"

$script:VenvRoot = Join-Path $DevEnvRoot "venvs\ZhaiXing"
$script:VenvPython = Join-Path $VenvRoot "Scripts\python.exe"

# 与 .env / docker-compose 默认账号一致
$script:JavaRoot = Join-Path $DevEnvRoot "Java21"
$script:MySqlDatabase = "meeting_assistant"
$script:MySqlUser = "zx"
$script:MySqlPassword = "zxpass"
$script:MySqlRootPassword = "root"
$script:MySqlPort = 3306
$script:RedisPort = 6379

function Get-MySqlBinDir {
    if (Test-Path $script:MySqlInstallMarker) {
        $rel = (Get-Content $script:MySqlInstallMarker -Raw).Trim()
        return Join-Path $script:MySqlRoot $rel
    }
    $found = Get-ChildItem -Path $script:MySqlRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName "bin\mysqld.exe") } |
        Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null
}

function Get-MySqlExe([string]$name) {
    $bin = Get-MySqlBinDir
    if (-not $bin) { return $null }
    return Join-Path $bin "bin\$name"
}
