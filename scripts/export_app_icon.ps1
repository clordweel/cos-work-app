# 从 assets/brand/cos_logo_favicon.svg（与 vendor/cos 同源）导出 1024 PNG，并重新生成 Android 启动图标。
# 依赖：Node.js（npx svgexport）。在 cos-work-app 根目录执行：.\scripts\export_app_icon.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root
$svg = Join-Path $root 'assets\brand\cos_logo_favicon.svg'
$png = Join-Path $root 'assets\brand\app_icon_source.png'
if (-not (Test-Path -LiteralPath $svg)) {
    Write-Host "缺少 $svg，请从 vendor/cos/cos/public/images/cos_logo_favicon.svg 复制。" -ForegroundColor Yellow
    exit 1
}
npx --yes svgexport $svg $png 1024:1024
dart run flutter_launcher_icons
Write-Host '完成：app_icon_source.png 与 mipmap 已更新。' -ForegroundColor Green
