# 打 Android release APK 或 App Bundle。若缺少 android/key.properties，Gradle 会回退 debug 签名（仅本地调试用）。
# 用法:
#   .\scripts\build_android_release.ps1
#   .\scripts\build_android_release.ps1 -AppBundle

param(
    [switch]$AppBundle
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Test-Path "android/key.properties")) {
    Write-Warning "未找到 android/key.properties，release 将使用 debug 签名。内测/上架前请复制 key.properties.example 并配置正式 keystore。"
}

if ($AppBundle) {
    flutter build appbundle --release
} else {
    flutter build apk --release
}
