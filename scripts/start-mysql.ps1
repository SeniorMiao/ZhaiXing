param(
    [switch]$InitAccounts
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\env-paths.ps1"

$mysqld = Get-MySqlExe "mysqld.exe"
$mysql = Get-MySqlExe "mysql.exe"
if (-not $mysqld) {
    Write-Host "未安装 MySQL，请先执行: install-mysql.ps1"
    exit 1
}

$tcp = Test-NetConnection -ComputerName 127.0.0.1 -Port $MySqlPort -WarningAction SilentlyContinue
if ($tcp.TcpTestSucceeded) {
    Write-Host "MySQL 已在运行 (127.0.0.1:$MySqlPort)"
}
else {
    Write-Host "启动 MySQL -> $MySqlData"
    Start-Process -FilePath $mysqld -ArgumentList "--defaults-file=$MySqlIni" -WindowStyle Minimized

    $deadline = (Get-Date).AddSeconds(60)
    $ready = $false
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 2
        $tcp = Test-NetConnection -ComputerName 127.0.0.1 -Port $MySqlPort -WarningAction SilentlyContinue
        if ($tcp.TcpTestSucceeded) { $ready = $true; break }
    }
    if (-not $ready) {
        Write-Warning "MySQL 端口 $MySqlPort 未就绪，请查看错误日志: $MySqlData\*.err"
        exit 1
    }
    Write-Host "MySQL 已监听 127.0.0.1:$MySqlPort"
}

if ($InitAccounts) {
    $args = @("--defaults-file=$MySqlIni", "-u", "root", "--protocol=tcp")
    & $mysql @args -e "SELECT 1" 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $args = @("--defaults-file=$MySqlIni", "-u", "root", "-p$MySqlRootPassword", "--protocol=tcp")
    }

    $statements = @(
        "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MySqlRootPassword';",
        "CREATE DATABASE IF NOT EXISTS ``$MySqlDatabase`` DEFAULT CHARACTER SET utf8mb4;",
        "CREATE USER IF NOT EXISTS '$MySqlUser'@'localhost' IDENTIFIED BY '$MySqlPassword';",
        "GRANT ALL PRIVILEGES ON ``$MySqlDatabase``.* TO '$MySqlUser'@'localhost';",
        "FLUSH PRIVILEGES;"
    )
    foreach ($stmt in $statements) {
        & $mysql @args -e $stmt
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "SQL 可能已执行过（可忽略重复错误）: $stmt"
        }
    }
    Write-Host "已配置库 $MySqlDatabase 与用户 $MySqlUser"
}
