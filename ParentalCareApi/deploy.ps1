[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AppName,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup = "RemoteCaregiverRG"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectDir = $PSScriptRoot
$publishDir = Join-Path $projectDir "publish"
$zipPath = Join-Path $projectDir "deploy.zip"

function Write-Step([string]$message) {
    Write-Host "==> $message" -ForegroundColor Cyan
}

function New-PosixZipFromFolder([string]$sourceDir, [string]$destinationZip) {
    Add-Type -AssemblyName System.IO.Compression

    if (Test-Path $destinationZip) {
        Remove-Item $destinationZip -Force
    }

    $fileStream = [System.IO.File]::Open($destinationZip, [System.IO.FileMode]::CreateNew)
    try {
        $archive = [System.IO.Compression.ZipArchive]::new(
            $fileStream,
            [System.IO.Compression.ZipArchiveMode]::Create,
            $false
        )
        try {
            $files = Get-ChildItem -Path $sourceDir -Recurse -File
            foreach ($file in $files) {
                $relative = $file.FullName.Substring($sourceDir.Length).TrimStart('\', '/')
                $entryName = $relative.Replace('\', '/')

                $entry = $archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
                $entryStream = $entry.Open()
                try {
                    $inStream = [System.IO.File]::OpenRead($file.FullName)
                    try {
                        $inStream.CopyTo($entryStream)
                    }
                    finally {
                        $inStream.Dispose()
                    }
                }
                finally {
                    $entryStream.Dispose()
                }
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    finally {
        $fileStream.Dispose()
    }
}

function Assert-ValidAzureZipPackage([string]$zipFilePath) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipFilePath)
    try {
        $entries = $zip.Entries
        $hasBackslashes = $entries | Where-Object { $_.FullName.Contains('\\') } | Select-Object -First 1
        if ($hasBackslashes) {
            throw "ZIP contains Windows path separators: '$($hasBackslashes.FullName)'. Recreate zip with POSIX separators."
        }

        $hasRootDll = $entries | Where-Object { $_.FullName -eq 'ParentalCareApi.dll' } | Select-Object -First 1
        if (-not $hasRootDll) {
            $dllLike = $entries | Where-Object { $_.FullName -like '*ParentalCareApi.dll' } | Select-Object -First 5 -ExpandProperty FullName
            $hint = if ($dllLike) { "Found: $($dllLike -join ', ')" } else { "Not found anywhere in ZIP." }
            throw "ParentalCareApi.dll is not at the ZIP root. This usually happens if you zipped the publish folder itself instead of its contents. $hint"
        }
    }
    finally {
        $zip.Dispose()
    }
}

Write-Step "Publishing backend (Linux-friendly publish output)"
if (Test-Path $publishDir) {
    Remove-Item $publishDir -Recurse -Force
}

Push-Location $projectDir
try {
    # UseAppHost=false prevents generating a Windows .exe apphost (Azure Linux runs: dotnet ParentalCareApi.dll)
    dotnet publish -c Release -o $publishDir -p:UseAppHost=false
}
finally {
    Pop-Location
}

Write-Step "Creating deploy.zip (POSIX path separators)"
New-PosixZipFromFolder -sourceDir $publishDir -destinationZip $zipPath
Write-Step "Validating deploy.zip"
Assert-ValidAzureZipPackage -zipFilePath $zipPath

Write-Step "Deploying to Azure App Service ($ResourceGroup/$AppName)"
try {
    az webapp deploy --resource-group $ResourceGroup --name $AppName --src-path $zipPath --type zip --clean true --restart true | Out-Null
}
catch {
    Write-Warning "az webapp deploy failed; falling back to classic zipdeploy (config-zip)."
    az webapp deployment source config-zip --resource-group $ResourceGroup --name $AppName --src $zipPath | Out-Null
}

Write-Step "Done"
Write-Host "Health check: https://$AppName.azurewebsites.net/health"