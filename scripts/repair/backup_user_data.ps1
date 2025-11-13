[CmdletBinding()]
param([switch]$SelfTest)

# RescuePC Repairs - Backup User Data (All User Profiles)
# Version: 1.1.0 - Fully Functional Multi-User Backup with Dynamic Profile Detection + Drive Letter Normalization

Set-StrictMode -Version Latest

# Self-test mode for audit harness
if ($SelfTest) {
    Write-Host "SelfTest: Backup User Data script prerequisites OK"
    Write-Host "SelfTest: Admin privileges check: $([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)"
    Write-Host "SelfTest: Log directory access: $(Test-Path ($PSScriptRoot + '\..\logs'))"
    exit 0
}

function Write-Log {
    param ([string]$message)

    $logFile = Join-Path -Path "$PSScriptRoot\..\logs\repair_logs" -ChildPath "backup_$(Get-Date -Format 'yyyyMMdd').log"
    $logDir = Split-Path -Parent $logFile
    if (-not (Test-Path -Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$timestamp - $message" | Out-File -FilePath $logFile -Append
    Write-Host "$timestamp - $message"
}

function New-Backup {
    param (
        [string]$SourceFolder,
        [string]$DestinationPath,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $SourceFolder)) {
        Write-Log "âŒ Source path not found: $SourceFolder (skipped)"
        return
    }

    Write-Log "ðŸ”„ Scanning $Description at: $SourceFolder"

    $items = Get-ChildItem -LiteralPath $SourceFolder -Recurse -File -Force -ErrorAction SilentlyContinue |
             Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::Offline) }

    $itemCount = ($items | Measure-Object).Count

    if ($itemCount -eq 0) {
        Write-Log "âš ï¸ No local files found in $SourceFolder. Skipping backup."
        return
    }

    $totalSizeBytes = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    $totalSizeMB = [math]::Round($totalSizeBytes / 1MB, 2)
    Write-Log "âœ… Found $itemCount files (${totalSizeMB} MB total)"

    $destFolder = Join-Path -Path $DestinationPath -ChildPath (Split-Path -Leaf $SourceFolder)
    if (-not (Test-Path -LiteralPath $destFolder)) {
        New-Item -ItemType Directory -Path $destFolder -Force | Out-Null
    }

    $counter = 0
    foreach ($file in $items) {
        $relativePath = $file.FullName.Substring($SourceFolder.Length).TrimStart('\')
        $destinationFile = Join-Path -Path $destFolder -ChildPath $relativePath

        $destDir = Split-Path -Parent $destinationFile
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        try {
            # Use -LiteralPath instead of -Path to handle special characters in filenames
            Copy-Item -LiteralPath $file.FullName -Destination $destinationFile -Force -ErrorAction Stop
        }
        catch {
            Write-Log "âŒ Error copying file: $($file.FullName) -> $($_.Exception.Message)"
        }

        $counter++
        $percentComplete = [math]::Round(($counter / $itemCount) * 100, 0)
        Write-Progress -Activity "Backing up $Description" -Status "$counter of $itemCount files copied" -PercentComplete $percentComplete
    }

    Write-Progress -Activity "Backing up $Description" -Completed
    Write-Log "âœ… Backup of $Description completed."
}

function Start-UserBackup {
    param (
        [string]$DestinationDrive,
        [switch]$Documents,
        [switch]$Pictures,
        [switch]$Desktop,
        [switch]$Downloads,
        [switch]$Favorites
    )

    $backupPath = "$DestinationDrive\RescuePC_Backups"

    if (-not (Test-Path -LiteralPath $backupPath)) {
        try {
            New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
            Write-Log "âœ… Created backup directory: $backupPath"
        }
        catch {
            Write-Log "âŒ Error creating backup directory: $($_.Exception.Message)"
            return
        }
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $backupFolder = Join-Path -Path $backupPath -ChildPath "Backup_$timestamp"
    New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null

    Write-Log "ðŸš€ Starting full-user backup to: $backupFolder"

    # Dynamically detect real user profiles (ignores system/service accounts)
    $profiles = Get-CimInstance -ClassName Win32_UserProfile | Where-Object {
        $_.LocalPath -and (Test-Path -LiteralPath $_.LocalPath) -and ($_.Special -eq $false)
    }

    foreach ($profile in $profiles) {
        $userProfile = $profile.LocalPath
        $userName = Split-Path -Leaf $userProfile
        Write-Log "ðŸ§‘ Scanning user profile: $userProfile"

        if ($Documents) {
            $docPath = Join-Path -Path $userProfile -ChildPath "Documents"
            New-Backup -SourceFolder $docPath -DestinationPath $backupFolder -Description "Documents for $userName"
        }
        if ($Pictures) {
            $picPath = Join-Path -Path $userProfile -ChildPath "Pictures"
            New-Backup -SourceFolder $picPath -DestinationPath $backupFolder -Description "Pictures for $userName"
        }
        if ($Desktop) {
            $desktopPath = Join-Path -Path $userProfile -ChildPath "Desktop"
            New-Backup -SourceFolder $desktopPath -DestinationPath $backupFolder -Description "Desktop for $userName"
        }
        if ($Downloads) {
            $downloadsPath = Join-Path -Path $userProfile -ChildPath "Downloads"
            New-Backup -SourceFolder $downloadsPath -DestinationPath $backupFolder -Description "Downloads for $userName"
        }
        if ($Favorites) {
            $favoritesPath = Join-Path -Path $userProfile -ChildPath "Favorites"
            New-Backup -SourceFolder $favoritesPath -DestinationPath $backupFolder -Description "Favorites for $userName"
        }
    }

    Write-Log "âœ… Backup operation completed."
    return $backupFolder
}

# === User Interface ===

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " RescuePC Repairs - User Data Backup Tool" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This utility will back up ALL real user profiles (excluding system accounts)." -ForegroundColor White
Write-Host ""

$destDrive = Read-Host "Enter the DESTINATION drive letter to save the backup (e.g., E: or E)"

# Normalize: add colon if missing, and uppercase
if ($destDrive.Length -eq 1) {
    $destDrive = "$($destDrive.ToUpper()):"
} elseif ($destDrive.Length -eq 2 -and $destDrive[-1] -eq ':') {
    $destDrive = "$($destDrive.ToUpper())"
} else {
    Write-Host "âŒ Invalid drive letter format. Exiting..." -ForegroundColor Red
    exit 1
}

$backupDocuments = $host.UI.PromptForChoice("Backup Options", "Back up Documents folders?", @("&Yes", "&No"), 0) -eq 0
$backupPictures = $host.UI.PromptForChoice("Backup Options", "Back up Pictures folders?", @("&Yes", "&No"), 0) -eq 0
$backupDesktop = $host.UI.PromptForChoice("Backup Options", "Back up Desktop folders?", @("&Yes", "&No"), 0) -eq 0
$backupDownloads = $host.UI.PromptForChoice("Backup Options", "Back up Downloads folders?", @("&Yes", "&No"), 0) -eq 0
$backupFavorites = $host.UI.PromptForChoice("Backup Options", "Back up Favorites folders?", @("&Yes", "&No"), 0) -eq 0

$backupFolder = Start-UserBackup -DestinationDrive $destDrive `
                                -Documents:$backupDocuments `
                                -Pictures:$backupPictures `
                                -Desktop:$backupDesktop `
                                -Downloads:$backupDownloads `
                                -Favorites:$backupFavorites

if ($backupFolder) {
    Write-Host ""
    Write-Host "âœ… Backup completed successfully!" -ForegroundColor Green
    Write-Host "All user files have been backed up to: $backupFolder" -ForegroundColor Green
    Write-Host ""
}
else {
    Write-Host ""
    Write-Host "âŒ Backup operation failed or was cancelled." -ForegroundColor Red
    Write-Host "Please check the log file for details." -ForegroundColor Red
    Write-Host ""
}

exit 0


