# 使用 Windows 自带 curl（Schannel），部分环境下比 Java 下载更不易触发 PKIX
# 输出到 ../gradle/wrapper/，与 gradle-wrapper.properties 同目录（distributionUrl 只用文件名）
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$androidRoot = Split-Path -Parent $here
$wrapperDir = Join-Path $androidRoot "gradle\wrapper"
$null = New-Item -ItemType Directory -Force -Path $wrapperDir
$out = Join-Path $wrapperDir "gradle-8.14-all.zip"
$url = "https://services.gradle.org/distributions/gradle-8.14-all.zip"
Write-Host "Downloading to $out ..."
# --ssl-no-revoke：部分 Windows 会出现 CRYPT_E_NO_REVOCATION_CHECK，导致默认校验失败
curl.exe -fL --ssl-no-revoke --retry 3 --connect-timeout 30 "$url" -o "$out"
Write-Host "OK: $((Get-Item $out).Length) bytes"
