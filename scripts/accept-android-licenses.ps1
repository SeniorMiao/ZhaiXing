$ErrorActionPreference = "Stop"
. "$PSScriptRoot\env-paths.ps1"

$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { Join-Path $env:LOCALAPPDATA "Android\Sdk" }
$licensesDir = Join-Path $sdk "licenses"

if (-not (Test-Path $sdk)) {
    New-Item -ItemType Directory -Path $sdk -Force | Out-Null
}
New-Item -ItemType Directory -Path $licensesDir -Force | Out-Null

$licenseFiles = @{
    "android-sdk-license" = "24333f8a63b6825ea9c5514f83c2829b004d1fee"
    "android-sdk-preview-license" = "84831b940964895a445ea5e64ec585d50f9b50"
    "android-googletv-license" = "601085b94cd77f0b54ff86406957099ebe059c2"
    "android-sdk-arm-dbt-license" = "84831b940964895a445ea5e64ec585d50f9b50"
    "google-gdk-license" = "33b6a2b64607a11ff7970b2953766312"
    "intel-android-extra-license" = "d9750adc42661e2f8b8181b6250d9a58"
    "android-ndk-license" = "24333f8a63b6825ea9c5514f83c2829b004d1fee"
}

foreach ($entry in $licenseFiles.GetEnumerator()) {
    $path = Join-Path $licensesDir $entry.Key
    Set-Content -Path $path -Value $entry.Value -NoNewline -Encoding ascii
}

Write-Host "已写入 Android SDK 许可: $licensesDir"
Write-Host "SDK 路径: $sdk"
