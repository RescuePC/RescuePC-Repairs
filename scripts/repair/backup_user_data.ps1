[CmdletBinding()]
param(
    [string]$BackupRoot
)

Write-Host "=== RescuePC - User Data Backup ===" -ForegroundColor Cyan

if (-not $BackupRoot -or $BackupRoot.Trim() -eq "") {
    $BackupRoot = Read-Host "Enter backup destination folder (example: E:\RescuePC-Backups)"
}

$BackupRoot = $BackupRoot.Trim()

if (-not (Test-Path -LiteralPath $BackupRoot)) {
    try {
        New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
    } catch {
        Write-Error "Failed to create backup directory: $BackupRoot. Error: $($_.Exception.Message)"
        exit 1
    }
}

$FoldersToBackup = @(
    "$env:UserProfile\Desktop",
    "$env:UserProfile\Documents",
    "$env:UserProfile\Pictures"
)

$timestamp    = Get-Date -Format "yyyyMMdd_HHmmss"
$sessionFolder = Join-Path $BackupRoot "$env:COMPUTERNAME\$timestamp"
New-Item -ItemType Directory -Path $sessionFolder -Force | Out-Null

$overallSuccess = $true

foreach ($source in $FoldersToBackup) {
    if (-not (Test-Path -LiteralPath $source)) {
        Write-Warning "Skipping (not found): $source"
        continue
    }

    $folderName = Split-Path $source -Leaf
    $dest       = Join-Path $sessionFolder $folderName
    New-Item -ItemType Directory -Path $dest -Force | Out-Null

    $robocopyArgs = @(
        "`"$source`"",
        "`"$dest`"",
        "/E", "/COPY:DAT", "/R:2", "/W:5", "/XO", "/NP", "/NFL", "/NDL"
    )

    $proc = Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopyArgs -Wait -PassThru
    if ($proc.ExitCode -gt 7) {
        $overallSuccess = $false
        Write-Warning "robocopy reported an error for $source (ExitCode: $($proc.ExitCode))"
    }
}

if ($overallSuccess) {
    Write-Host "Backup completed successfully." -ForegroundColor Green
    Write-Host "Session folder: $sessionFolder"
    exit 0
} else {
    Write-Error "Backup finished with one or more errors."
    exit 1
}
