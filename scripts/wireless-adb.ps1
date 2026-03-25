# Wireless ADB helper for cos-work-app (uses SDK platform-tools; no PATH needed).
# Phone: Developer options - Wireless debugging.
#   1) Pair: use pairing code, then: .\scripts\wireless-adb.ps1 pair -Endpoint IP:PAIR_PORT
#   2) Connect: use IP:PORT on wireless debugging screen: .\scripts\wireless-adb.ps1 connect -Endpoint IP:DEBUG_PORT
#   3) Run app: .\scripts\wireless-adb.ps1 run

param(
    [Parameter(Position = 0)]
    [ValidateSet('devices', 'pair', 'connect', 'tcpip', 'flutter-devices', 'run')]
    [string] $Action = 'devices',

    [string] $Endpoint = '',
    [string] $AdbPath = ''
)

$ErrorActionPreference = 'Stop'

if (-not $AdbPath) {
    $sdk = $env:ANDROID_HOME
    if (-not $sdk) { $sdk = "$env:LOCALAPPDATA\Android\sdk" }
    $AdbPath = Join-Path $sdk 'platform-tools\adb.exe'
}

if (-not (Test-Path -LiteralPath $AdbPath)) {
    Write-Host "adb not found: $AdbPath" -ForegroundColor Yellow
    Write-Host 'Install Android SDK Platform-Tools or set ANDROID_HOME.' -ForegroundColor Yellow
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

function Invoke-Adb {
    param([string[]] $AdbArguments)
    & $AdbPath @AdbArguments
}

switch ($Action) {
    'devices' {
        Write-Host 'adb devices -l' -ForegroundColor Cyan
        Invoke-Adb -AdbArguments @('devices', '-l')
    }
    'pair' {
        if (-not $Endpoint) {
            Write-Host 'Usage: .\scripts\wireless-adb.ps1 pair -Endpoint IP:PAIR_PORT' -ForegroundColor Yellow
            exit 1
        }
        Write-Host "adb pair $Endpoint" -ForegroundColor Cyan
        Invoke-Adb -AdbArguments @('pair', $Endpoint)
    }
    'connect' {
        if (-not $Endpoint) {
            Write-Host 'Usage: .\scripts\wireless-adb.ps1 connect -Endpoint IP:DEBUG_PORT' -ForegroundColor Yellow
            exit 1
        }
        Write-Host "adb connect $Endpoint" -ForegroundColor Cyan
        Invoke-Adb -AdbArguments @('connect', $Endpoint)
    }
    'tcpip' {
        Write-Host 'USB required first. Then: adb connect PHONE_IP:5555' -ForegroundColor Cyan
        Invoke-Adb -AdbArguments @('tcpip', '5555')
    }
    'flutter-devices' {
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
        Set-Location $projectRoot
        flutter devices
    }
    'run' {
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
        Set-Location $projectRoot
        flutter pub get
        flutter run
    }
}
