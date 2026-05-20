$ErrorActionPreference = "Stop"
. "$PSScriptRoot\env-paths.ps1"

$FlutterGitMirror = "https://mirrors.tuna.tsinghua.edu.cn/git/flutter-sdk.git"
$FlutterBat = Join-Path $FlutterBin "flutter.bat"

function Ensure-Git {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "需要 Git: https://git-scm.com"
    }
}

function Clone-FlutterRepo([string]$targetDir) {
    $urls = @(
        $FlutterGitMirror,
        "https://github.com/flutter/flutter.git"
    )
    foreach ($url in $urls) {
        Write-Host "尝试克隆: $url"
        try {
            if (Test-Path (Join-Path $targetDir ".git")) {
                Remove-Item -Recurse -Force (Join-Path $targetDir ".git") -ErrorAction SilentlyContinue
            }
            git clone $url -b stable --depth 1 $targetDir
            if (Test-Path (Join-Path $targetDir "bin\flutter.bat")) {
                Push-Location $targetDir
                git remote set-url origin $FlutterGitMirror
                git remote -v
                Pop-Location
                return
            }
        }
        catch {
            Write-Warning $_.Exception.Message
        }
    }
    throw "克隆失败。请检查网络后重试，或手动克隆到 $FlutterRoot 并执行 git remote set-url origin $FlutterGitMirror"
}

function Install-FlutterSdk {
    Ensure-Git
    $parent = Split-Path $FlutterRoot -Parent
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if (-not (Test-Path $FlutterRoot)) {
        New-Item -ItemType Directory -Path $FlutterRoot -Force | Out-Null
    }

    $isEmpty = -not (Get-ChildItem $FlutterRoot -Force -ErrorAction SilentlyContinue)
    if ($isEmpty) {
        Clone-FlutterRepo $FlutterRoot
    }
    else {
        Clone-FlutterRepo $FlutterRoot
    }
}

function Set-FlutterUserEnv {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$FlutterBin*") {
        $newPath = if ([string]::IsNullOrWhiteSpace($userPath)) { $FlutterBin } else { "$FlutterBin;$userPath" }
        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        Write-Host "已写入用户 PATH: $FlutterBin"
    }
  else {
        Write-Host "用户 PATH 已包含 Flutter bin"
    }

    [Environment]::SetEnvironmentVariable("PUB_HOSTED_URL", "https://pub.flutter-io.cn", "User")
    [Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", "https://storage.flutter-io.cn", "User")
    [Environment]::SetEnvironmentVariable("FLUTTER_GIT_URL", $FlutterGitMirror, "User")
    if (-not (Test-Path $PubCacheRoot)) {
        New-Item -ItemType Directory -Path $PubCacheRoot -Force | Out-Null
    }
    [Environment]::SetEnvironmentVariable("PUB_CACHE", $PubCacheRoot, "User")
    Write-Host "已设置 PUB_HOSTED_URL / FLUTTER_STORAGE_BASE_URL / FLUTTER_GIT_URL / PUB_CACHE"

    $env:Path = "$FlutterBin;" + $env:Path
    $env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
    $env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
    $env:FLUTTER_GIT_URL = $FlutterGitMirror
    $env:PUB_CACHE = $PubCacheRoot
}

function Initialize-FlutterCache {
    if (-not (Test-Path $FlutterBat)) { return }
    $cacheDart = Join-Path $FlutterRoot "bin\cache\dart-sdk"
    if (Test-Path $cacheDart) {
        Write-Host "Flutter 缓存已存在，跳过首次下载。"
        return
    }
    Write-Host "首次运行 flutter，下载 Dart SDK 与工具链（需几分钟）..."
    & $FlutterBat --version | Out-Host
    if (-not (Test-Path $cacheDart)) {
        throw "Flutter 仍不完整。请检查网络后重试: flutter --version"
    }
    Write-Host "Flutter SDK 已完整，可在 Android Studio 中保存路径。"
}

if (Test-Path $FlutterBat) {
    Write-Host "Flutter 已存在: $FlutterRoot"
}
else {
    Install-FlutterSdk
}

if (Test-Path (Join-Path $FlutterRoot ".git")) {
    Push-Location $FlutterRoot
    git remote set-url origin $FlutterGitMirror
    Write-Host "remote origin -> $FlutterGitMirror"
    git remote -v
    Pop-Location
}

Set-FlutterUserEnv
Initialize-FlutterCache

Write-Host ""
Write-Host "请关闭并重新打开 Android Studio，再在 Flutter SDK 填: $FlutterRoot"
Write-Host ""
& $FlutterBat doctor -v
Write-Host ""
Write-Host "Android Studio -> Settings -> Flutter -> SDK path:"
Write-Host "  $FlutterRoot"
Write-Host ""
Write-Host "下一步:"
Write-Host "  cd $MobileRoot"
Write-Host "  flutter pub get"
Write-Host "  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000"
