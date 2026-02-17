[CmdletBinding()]
param(
    [string]$DeviceId = "emulator-5554",
    [string]$PackageName = "com.parentalcare.parentalCareApp",
    [ValidateSet("debug", "profile", "release")]
    [string]$Mode = "debug"
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

    $fallback = "C:\Users\tejaslunawat\AppData\Local\Android\Sdk\platform-tools\adb.exe"
    if (Test-Path $fallback) { return $fallback }

    throw "adb.exe not found. Set ANDROID_HOME or install Android platform-tools."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$adb = Resolve-AdbPath

Write-Step "Checking device '$DeviceId'"
& $adb devices | Out-String | Write-Host
$state = (& $adb -s $DeviceId get-state 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $state) {
    throw "Device '$DeviceId' not reachable via adb. Run: flutter devices"
}

Write-Step "Force-stopping and uninstalling $PackageName"
try { & $adb -s $DeviceId shell am force-stop $PackageName | Out-Null } catch {}
try { & $adb -s $DeviceId shell pm clear $PackageName | Out-Null } catch {}
try { & $adb -s $DeviceId shell pm uninstall --user 0 $PackageName | Out-Null } catch {}

Write-Step "Removing external storage traces (Android/data + Android/obb)"
try {
    & $adb -s $DeviceId shell rm -rf "/sdcard/Android/data/$PackageName" "/sdcard/Android/obb/$PackageName" | Out-Null
} catch {}

Write-Step "Flutter clean + deps"
Push-Location $repoRoot
try {
    flutter clean
    flutter pub get

    Write-Step "Fresh install/run ($Mode)"
    $modeFlag = "--$Mode"
    flutter run -d $DeviceId $modeFlag
}
finally {
    Pop-Location
}
