# cos-work-app 开发环境配置（Scoop）
# 前置：已安装 Scoop (https://scoop.sh)
# 用法：.\scripts\setup-env.ps1

$ErrorActionPreference = "Stop"

Write-Host "`n=== cos-work-app 开发环境配置 (Scoop) ===" -ForegroundColor Cyan

# 1. 检查 Scoop
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Scoop 未安装。请先运行：" -ForegroundColor Yellow
    Write-Host "  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Gray
    Write-Host "  irm get.scoop.sh | iex" -ForegroundColor Gray
    exit 1
}

# 2. 添加 bucket
$buckets = @("extras", "java")
foreach ($b in $buckets) {
    if (-not (scoop bucket list 2>$null | Select-String -Pattern $b -Quiet)) {
        Write-Host "添加 bucket: $b" -ForegroundColor Green
        scoop bucket add $b
    }
}

# 3. 安装依赖
$packages = @("git", "openjdk17")
foreach ($p in $packages) {
    if (-not (scoop list 2>$null | Select-String -Pattern "Name=$p[;\s]" -Quiet)) {
        Write-Host "安装: $p" -ForegroundColor Green
        scoop install $p
    } else {
        Write-Host "已安装: $p" -ForegroundColor Gray
    }
}

# Flutter（若之前失败需先 scoop uninstall flutter）
$flutterStatus = scoop list 2>$null | Select-String -Pattern "flutter"
if ($flutterStatus -and $flutterStatus -match "Install failed") {
    Write-Host "清理失败的 Flutter 安装..." -ForegroundColor Yellow
    scoop uninstall flutter 2>$null
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "安装: flutter (约 1.7GB，请勿中断)" -ForegroundColor Green
    scoop install flutter
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Scoop 安装 Flutter 失败。请关闭其他占用 scoop 的进程后重试，或参考 README 手动安装。" -ForegroundColor Yellow
    }
} else {
    Write-Host "已安装: flutter" -ForegroundColor Gray
}

# 4. Android SDK（可选，若已有 Android Studio 可跳过）
# scoop 的 android-sdk 在 extras，若不存在可改用 Android Studio 自带 SDK
$androidSdk = "android-sdk"
if (-not (scoop list 2>$null | Select-String -Pattern $androidSdk -Quiet)) {
    try {
        Write-Host "安装: $androidSdk" -ForegroundColor Green
        scoop install $androidSdk
    } catch {
        Write-Host "android-sdk 安装失败或不存在，请使用 Android Studio 或手动配置 ANDROID_HOME" -ForegroundColor Yellow
    }
} else {
    Write-Host "已安装: $androidSdk" -ForegroundColor Gray
}

# 5. 刷新 PATH（当前会话）
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# 6. Flutter 配置
Write-Host "`n运行 flutter doctor..." -ForegroundColor Cyan
flutter doctor -v

Write-Host "`n若 Android 未就绪，执行: flutter doctor --android-licenses" -ForegroundColor Yellow
Write-Host "完成后运行: flutter pub get && flutter run" -ForegroundColor Green
