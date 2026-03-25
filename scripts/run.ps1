# cos-work-app 运行脚本
# 前置：setup-env.ps1 已完成，Flutter 已安装
# 用法：.\scripts\run.ps1

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

# 刷新 PATH（Scoop 安装后需新会话或手动刷新）
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

Set-Location $projectRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Flutter 未找到。请先运行: .\scripts\setup-env.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "flutter pub get..." -ForegroundColor Cyan
flutter pub get

Write-Host "`nflutter run (Android 真机/模拟器)..." -ForegroundColor Cyan
flutter run
