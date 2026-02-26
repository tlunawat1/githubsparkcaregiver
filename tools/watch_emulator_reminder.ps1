[CmdletBinding()]
param(
    [string]$DeviceId = "emulator-5554",
    [string]$PackageName = "com.parentalcare.parentalCareApp",
    [int]$OffsetMinutes = 2,
    [int]$WatchSeconds = 200
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Write-Step([string]$message) {
    Write-Host "==> $message" -ForegroundColor Cyan
}

function Resolve-AdbPath() {
    if ($env:ANDROID_HOME) {
        $candidate = Join-Path $env:ANDROID_HOME "platform-tools\adb.exe"
        if (Test-Path $candidate) { return $candidate }
    }

    $fallback = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $fallback) { return $fallback }

    throw "adb.exe not found. Set ANDROID_HOME or install Android platform-tools."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$logsDir = Join-Path $repoRoot "logs"
if (!(Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }

$adb = Resolve-AdbPath

Write-Step "Checking device '$DeviceId'"
$state = (& $adb -s $DeviceId get-state 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $state) {
    throw "Device '$DeviceId' not reachable via adb. Run: flutter devices"
}

Write-Step "Reading emulator time/timezone"
$nowStr = $null
$nowCompact = (& $adb -s $DeviceId shell date +%Y-%m-%dT%H:%M:%S) 2>$null
if ($nowCompact) {
    $nowStr = $nowCompact
} else {
    # Fallback to default date output (less parseable)
    $nowStr = (& $adb -s $DeviceId shell date) 2>$null
}
$tz = (& $adb -s $DeviceId shell getprop persist.sys.timezone) 2>$null
Write-Host "Emulator time: $nowStr" -ForegroundColor Yellow
Write-Host "Emulator TZ:   $tz" -ForegroundColor Yellow

# Try to compute suggested reminder time using epoch seconds.
$suggest = $null
$epoch = (& $adb -s $DeviceId shell date +%s) 2>$null
if ($epoch -match '^\d+$') {
    $targetEpoch = [int64]$epoch + ($OffsetMinutes * 60)
    # Convert using local machine timezone is fine for just HH:mm display.
    $target = [DateTimeOffset]::FromUnixTimeSeconds($targetEpoch).ToLocalTime().DateTime
    $suggest = $target.ToString("HH:mm")
    Write-Host "Set reminder time to (now + $OffsetMinutes min): $suggest" -ForegroundColor Green
} else {
    Write-Host "Could not read epoch time from emulator; set reminder time to now + $OffsetMinutes minutes." -ForegroundColor Green
}

Write-Step "Starting logcat capture for $WatchSeconds seconds"
& $adb -s $DeviceId logcat -c | Out-Null
$outFile = Join-Path $logsDir ("reminder-fcm-watch-{0}.txt" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
$proc = Start-Process -FilePath $adb -ArgumentList @("-s", $DeviceId, "logcat", "-v", "time") -NoNewWindow -RedirectStandardOutput $outFile -PassThru

Write-Host "Logcat -> $outFile" -ForegroundColor Yellow
Write-Host "Now: create a reminder in the app for the time above (title e.g. 'Tejas'), then wait..." -ForegroundColor Yellow

Start-Sleep -Seconds $WatchSeconds

Write-Step "Stopping logcat capture"
try { Stop-Process -Id $proc.Id -Force } catch {}

Write-Step "Extracting relevant lines"
$patterns = @(
    $PackageName,
    "FirebaseMessaging",
    "FCM",
    "GCM",
    "Notification",
    "flutter_local_notifications",
    "AlarmManager",
    "WorkManager",
    "JobScheduler",
    "AndroidRuntime",
    "FATAL EXCEPTION"
)

$regex = ($patterns | ForEach-Object { [Regex]::Escape($_) }) -join "|"
$hits = Select-String -Path $outFile -Pattern $regex -SimpleMatch:$false -ErrorAction SilentlyContinue

if (-not $hits) {
    Write-Host "No matching notification/FCM lines found in capture." -ForegroundColor Red
    exit 0
}

$hits | Select-Object -Last 200 | ForEach-Object { $_.Line } | Out-String | Write-Host

Write-Step "Done"
Write-Host "If you didn't receive a notification, paste the output above (or share $outFile)." -ForegroundColor Yellow
