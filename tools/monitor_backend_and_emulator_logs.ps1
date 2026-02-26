[CmdletBinding()]
param(
  [string]$AppName = 'RemoteCareGiver-api',
  [string]$ResourceGroup = 'RemoteCaregiverRG',
  [string]$DeviceId = 'emulator-5554',
  [string]$PackageName = 'com.parentalcare.parentalCareApp',
  [int]$Minutes = 15
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step([string]$message) {
  Write-Host "==> $message" -ForegroundColor Cyan
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$logsDir = Join-Path $repoRoot 'logs'
if (!(Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }

$adb = 'C:\Users\tejaslunawat\AppData\Local\Android\Sdk\platform-tools\adb.exe'
if (!(Test-Path $adb)) {
  $adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
}
if (!(Test-Path $adb)) {
  throw "adb.exe not found. Install Android platform-tools or set ANDROID_HOME."
}

$backendLog = Join-Path $logsDir ('backend-live-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$emulatorLog = Join-Path $logsDir ('emulator-live-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

# Keep output tight: only lines that indicate reminders/FCM/alarm/overlay activity.
$backendPattern = 'Sent reminder notification|Skipping notification|FCM|Firebase|Hangfire|Auto-marked|missed|snoozed|Error|Exception|NotificationJobService|NotificationService'
$emulatorPattern = 'Background message received|Foreground message received|Notification tapped|Local notification tapped|Urgent reminder|Local urgent|triggering alarm|ReminderAlarmService|queueing alarm|Starting queued alarm|flutter_local_notifications|OPEN_REMINDER|escalationLevel|reminder_alarm'

Write-Step "Clearing emulator logcat"
& $adb -s $DeviceId logcat -c | Out-Null

Write-Step "Starting emulator logcat capture -> $emulatorLog"
$adbProc = Start-Process -FilePath $adb -ArgumentList @('-s', $DeviceId, 'logcat', '-v', 'time') -NoNewWindow -RedirectStandardOutput $emulatorLog -PassThru

Write-Step "Starting backend log tail -> $backendLog"
# Use PowerShell to run az and redirect stdout to file.
$azArgs = @(
  '-NoProfile',
  '-Command',
  "az webapp log tail -n '$AppName' -g '$ResourceGroup'"
)
$azProc = Start-Process -FilePath 'powershell' -ArgumentList $azArgs -NoNewWindow -RedirectStandardOutput $backendLog -PassThru

Write-Step "Monitoring for $Minutes minutes (prints matches once per minute)"
$iterations = [Math]::Max(1, $Minutes)

for ($i = 1; $i -le $iterations; $i += 1) {
  Write-Host ("\n===== Minute {0}/{1} @ {2} =====" -f $i, $iterations, (Get-Date -Format 'HH:mm:ss')) -ForegroundColor Yellow

  try {
    $backendTail = Get-Content -Path $backendLog -Tail 200 -ErrorAction SilentlyContinue
    $backendHits = $backendTail | Select-String -Pattern $backendPattern -ErrorAction SilentlyContinue
    if ($backendHits) {
      Write-Host '--- Backend (matches) ---' -ForegroundColor Green
      $backendHits | Select-Object -Last 30 | ForEach-Object { $_.Line } | Write-Host
    } else {
      Write-Host '--- Backend: no matches ---' -ForegroundColor DarkGray
    }
  } catch {
    Write-Host "--- Backend tail error: $($_.Exception.Message)" -ForegroundColor Red
  }

  try {
    $emuTail = Get-Content -Path $emulatorLog -Tail 300 -ErrorAction SilentlyContinue
    $emuHits = $emuTail | Select-String -Pattern $emulatorPattern -ErrorAction SilentlyContinue
    if ($emuHits) {
      Write-Host '--- Emulator (matches) ---' -ForegroundColor Green
      $emuHits | Select-Object -Last 40 | ForEach-Object { $_.Line } | Write-Host
    } else {
      Write-Host '--- Emulator: no matches ---' -ForegroundColor DarkGray
    }
  } catch {
    Write-Host "--- Emulator tail error: $($_.Exception.Message)" -ForegroundColor Red
  }

  if ($i -lt $iterations) {
    Start-Sleep -Seconds 60
  }
}

Write-Step 'Stopping tails'
try { Stop-Process -Id $adbProc.Id -Force -ErrorAction SilentlyContinue } catch {}
try { Stop-Process -Id $azProc.Id -Force -ErrorAction SilentlyContinue } catch {}

Write-Step 'Done'
Write-Host "Backend log:  $backendLog" -ForegroundColor Yellow
Write-Host "Emulator log: $emulatorLog" -ForegroundColor Yellow
