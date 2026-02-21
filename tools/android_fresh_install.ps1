[CmdletBinding()]
param(
    [string]$DeviceId = "emulator-5554",
    [string[]]$DeviceIds,
    [string]$PackageName = "com.parentalcare.parentalCareApp",
    [ValidateSet("debug", "profile", "release")]
    [string]$Mode = "debug",
    [string]$ApkPath
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

$effectiveDeviceIds = if ($null -ne $DeviceIds -and $DeviceIds.Count -gt 0) { $DeviceIds } else { @($DeviceId) }

$repoRoot = Split-Path -Parent $PSScriptRoot
$adb = Resolve-AdbPath

Write-Step "ADB devices"
& $adb devices | Out-String | Write-Host

function Assert-DeviceReady([string]$id) {
    Write-Step "Checking device '$id'"
    $state = (& $adb -s $id get-state 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $state) {
        throw "Device '$id' not reachable via adb. Run: flutter devices"
    }
}

function Remove-AppTraces([string]$id) {
    Write-Step "[$id] Force-stop + clear + uninstall $PackageName"
    try { & $adb -s $id shell am force-stop $PackageName | Out-Null } catch {}
    try { & $adb -s $id shell pm clear $PackageName | Out-Null } catch {}
    try { & $adb -s $id shell pm uninstall --user 0 $PackageName | Out-Null } catch {}

    Write-Step "[$id] Removing external storage traces (Android/data + Android/obb + Android/media)"
    try {
        & $adb -s $id shell rm -rf "/sdcard/Android/data/$PackageName" "/sdcard/Android/obb/$PackageName" "/sdcard/Android/media/$PackageName" | Out-Null
    } catch {}
}

function Resolve-DefaultApkPath([string]$root, [string]$mode) {
    $fileName = switch ($mode) {
        "debug" { "app-debug.apk" }
        "profile" { "app-profile.apk" }
        "release" { "app-release.apk" }
        default { throw "Unsupported mode '$mode'" }
    }
    return (Join-Path $root (Join-Path "build\app\outputs\flutter-apk" $fileName))
}

foreach ($d in $effectiveDeviceIds) {
    Assert-DeviceReady $d
}

foreach ($d in $effectiveDeviceIds) {
    Remove-AppTraces $d
}

Push-Location $repoRoot
try {
    $apk = if ($ApkPath) { $ApkPath } else { Resolve-DefaultApkPath -root $repoRoot -mode $Mode }

    if (-not $ApkPath) {
        Write-Step "Flutter clean + deps"
        flutter clean
        flutter pub get

        Write-Step "Building APK ($Mode)"
        flutter build apk "--$Mode"
    }

    if (-not (Test-Path $apk)) {
        throw "APK not found at '$apk'. If you built elsewhere, pass -ApkPath explicitly."
    }

    foreach ($d in $effectiveDeviceIds) {
        Write-Step "[$d] Installing $apk"
        & $adb -s $d install -r -t $apk | Out-String | Write-Host
        if ($LASTEXITCODE -ne 0) {
            throw "adb install failed for '$d'"
        }

        Write-Step "[$d] Launching $PackageName"
        & $adb -s $d shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1 | Out-Null
    }
}
finally {
    Pop-Location
}
