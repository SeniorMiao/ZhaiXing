# 使用 Windows 自带 curl（Schannel），部分环境下比 Java 下载更不易触发 PKIX
# 输出到 ../gradle/wrapper/，与 gradle-wrapper.properties 同目录（distributionUrl 只用文件名）
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$androidRoot = Split-Path -Parent $here
$wrapperDir = Join-Path $androidRoot "gradle\wrapper"
$null = New-Item -ItemType Directory -Force -Path $wrapperDir
$out = Join-Path $wrapperDir "gradle-8.14-all.zip"
$urls = @(
    "https://services.gradle.org/distributions/gradle-8.14-all.zip",
    "https://mirrors.cloud.tencent.com/gradle/gradle-8.14-all.zip",
    "https://mirrors.tuna.tsinghua.edu.cn/gradle/gradle-8.14-all.zip"
)
$ok = $false
foreach ($url in $urls) {
    Write-Host "Downloading from $url"
    Write-Host "  -> $out"
    try {
        curl.exe -fL --ssl-no-revoke --retry 3 --connect-timeout 60 "$url" -o "$out"
        if ((Test-Path $out) -and (Get-Item $out).Length -gt 50MB) {
            $ok = $true
            break
        }
        Write-Warning "文件过小，尝试下一镜像..."
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}
if (-not $ok) {
    throw "下载失败。请浏览器打开 https://services.gradle.org/distributions/gradle-8.14-all.zip 保存到: $out"
}
Write-Host "OK: $((Get-Item $out).Length) bytes"
