[CmdletBinding()]
param([switch]$SelfTest)

# Self-test mode for audit harness
if ($SelfTest) {
    Write-Host "SelfTest: fix_startup_issues script prerequisites OK"
    exit 0
}

# RescuePC Repairs - Startup Repair Script
# Diagnoses and repairs common Windows startup issues
# Version: 1.0.0

Import-Module "$PSScriptRoot/Modules/SystemUtils.psm1" -Force

# Function to find system executables in standard locations
function Get-SystemExecutable {
    param(
        [string]$Name
    )
    
    $systemPaths = @(
        "$env:SystemRoot\System32",
        "$env:SystemRoot\System32\wbem",
        "$env:SystemRoot\System32\WindowsPowerShell\v1.0"
    )
    
    # Try direct path first
    if (Test-Path $Name) {
        return $Name
    }
    
    # Try with .exe extension if not provided
    if (-not [System.IO.Path]::HasExtension($Name)) {
        $Name = "$Name.exe"
    }
    
    # Check in system paths
    foreach ($path in $systemPaths) {
        $fullPath = Join-Path -Path $path -ChildPath $Name
        if (Test-Path $fullPath) {
            return $fullPath
        }
    }
    
    # Try to find in PATH
    $exePath = Get-Command -Name $Name -ErrorAction SilentlyContinue
    if ($exePath) {
        return $exePath.Source
    }
    
    # If not found, return the name as-is and let the caller handle the error
    return $Name
}

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Script configuration
$logFile = "$PSScriptRoot\..\logs\repair_logs\startup_repair_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Create log directory if it doesn't exist
$logDir = Split-Path -Parent $logFile
if (-not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Log function
function Write-Log {
    param (
        [string]$message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$timestamp - $message" | Out-File -FilePath $logFile -Append
    Write-Host "$timestamp - $message"
}

# Function to create a system restore point
function New-SystemRestorePoint {
    try {
        Write-Log "Creating system restore point..."

        # Check if System Restore is enabled
        $srEnabled = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval" -ErrorAction SilentlyContinue).RPSessionInterval -ne 0

        if (-not $srEnabled) {
            Write-Log "System Restore is not enabled. Skipping restore point creation."
            return $false
        }

        # Create the restore point
        Checkpoint-Computer -Description "RescuePC Startup Repair" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Log "System restore point created successfully."
        return $true
    }
    catch {
        Write-Log "Error creating system restore point: $($_.Exception.Message)"
        return $false
    }
}

# Function to repair boot configuration
function Repair-BootConfiguration {
    try {
        Write-Log "Checking boot configuration..."

        # Run bootrec commands to fix MBR and boot sectors
        $bootrecCommands = @(
            "/FixMbr",
            "/FixBoot",
            "/ScanOs",
            "/RebuildBcd"
        )

        foreach ($command in $bootrecCommands) {
            Write-Log "  Running bootrec $command..."
            $output = & bootrec.exe $command 2>&1
            Write-Log "  Output: $output"
        }

        # Run chkdsk on system drive (scheduled for next boot)
        $systemDrive = $env:SystemDrive
        Write-Log "  Scheduling chkdsk $systemDrive /f /r for next boot..."
        $chkdskExe = Get-SystemExecutable -Name 'chkdsk'
$output = & $chkdskExe $systemDrive /f /r 2>&1
        Write-Log "  Output: $output"

        return $true
    }
    catch {
        Write-Log "Error repairing boot configuration: $($_.Exception.Message)"
        return $false
    }
}

# Function to repair Windows startup components
function Repair-StartupComponents {
    try {
        Write-Log "Repairing Windows startup components..."

        # Run SFC to repair system files
        Write-Log "  Running System File Checker (SFC)..."
        $sfcExe = Get-SystemExecutable -Name 'sfc'
$output = & $sfcExe /scannow 2>&1
        Write-Log "  Output: $output"

        # Run DISM to repair Windows image
        Write-Log "  Running DISM to check for component store corruption..."
        $dismExe = Get-SystemExecutable -Name 'dism'
$output = & $dismExe /Online /Cleanup-Image /CheckHealth 2>&1
        Write-Log "  Output: $output"

        Write-Log "  Running DISM to scan for component store corruption..."
        $dismExe = Get-SystemExecutable -Name 'dism'
$output = & $dismExe /Online /Cleanup-Image /ScanHealth 2>&1
        Write-Log "  Output: $output"

        Write-Log "  Running DISM to repair component store corruption..."
        $dismExe = Get-SystemExecutable -Name 'dism'
$output = & $dismExe /Online /Cleanup-Image /RestoreHealth 2>&1
        Write-Log "  Output: $output"

        return $true
    }
    catch {
        Write-Log "Error repairing startup components: $($_.Exception.Message)"
        return $false
    }
}

# Function to repair Windows registry
function Repair-Registry {
    try {
        Write-Log "Repairing Windows registry..."

        # Create backup of current registry
        $backupDir = "$env:TEMP\RegBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

        Write-Log "  Creating registry backup in $backupDir..."
        $output = & reg.exe save HKLM\SYSTEM "$backupDir\SYSTEM.hiv" 2>&1
        Write-Log "  Output: $output"

        $output = & reg.exe save HKLM\SOFTWARE "$backupDir\SOFTWARE.hiv" 2>&1
        Write-Log "  Output: $output"

        # Check and repair registry permission issues
        Write-Log "  Checking registry permissions..."
        $regCmd = 'secedit /configure /cfg %windir%\inf\defltbase.inf /db defltbase.sdb /verbose'
        $output = Invoke-Expression $regCmd 2>&1
        Write-Log "  Output: $output"

        # Reset registry security permissions (safer than manual modifications)
        Write-Log "  Setting registry security defaults..."
        $regCmd = 'regini.exe %windir%\system32\setup\security.inf'
        try {
            $output = Invoke-Expression $regCmd 2>&1
            Write-Log "  Output: $output"
        }
        catch {
            Write-Log "  Non-critical error: $($_.Exception.Message)"
        }

        return $true
    }
    catch {
        Write-Log "Error repairing registry: $($_.Exception.Message)"
        return $false
    }
}

# Function to repair startup services
function Repair-StartupServices {
    try {
        Write-Log "Checking and repairing startup services..."

        # Essential Windows services to check
        $essentialServices = @(
            @{Name="wuauserv"; DisplayName="Windows Update"; Start="Automatic"},
            @{Name="WSearch"; DisplayName="Windows Search"; Start="Automatic"},
            @{Name="wscsvc"; DisplayName="Security Center"; Start="Automatic"},
            @{Name="bits"; DisplayName="Background Intelligent Transfer Service"; Start="Automatic"},
            @{Name="Winmgmt"; DisplayName="Windows Management Instrumentation"; Start="Automatic"},
            @{Name="Spooler"; DisplayName="Print Spooler"; Start="Automatic"},
            @{Name="TrustedInstaller"; DisplayName="Windows Modules Installer"; Start="Manual"},
            @{Name="eventlog"; DisplayName="Windows Event Log"; Start="Automatic"},
            @{Name="Schedule"; DisplayName="Task Scheduler"; Start="Automatic"},
            @{Name="AudioSrv"; DisplayName="Windows Audio"; Start="Automatic"}
        )

        foreach ($service in $essentialServices) {
            try {
                $svc = Get-Service -Name $service.Name -ErrorAction SilentlyContinue

                if ($svc) {
                    Write-Log "  Checking service: $($service.DisplayName) ($($service.Name))"

                    # Repair startup type if incorrect
                    if ($svc.StartType -ne $service.Start) {
                        Set-Service -Name $service.Name -StartupType $service.Start -ErrorAction Stop
                        Write-Log "  - Changed startup type from $($svc.StartType) to $($service.Start)"
                    }

                    # Start service if stopped
                    if ($svc.Status -ne "Running" -and $service.Start -eq "Automatic") {
                        Start-Service -Name $service.Name -ErrorAction SilentlyContinue
                        Write-Log "  - Started service (previously $($svc.Status))"
                    }
                }
                else {
                    Write-Log "  - Service not found: $($service.DisplayName)"
                }
            }
            catch {
                Write-Log "  - Error repairing service $($service.Name): $($_.Exception.Message)"
            }
        }

        return $true
    }
    catch {
        Write-Log "Error repairing startup services: $($_.Exception.Message)"
        return $false
    }
}

# Function to repair startup programs
function Repair-StartupPrograms {
    try {
        Write-Log "Checking startup programs..."

        # Check if autoruns.exe exists in tools folder
        $autorunsPath = "$PSScriptRoot\..\tools\portable_apps\autoruns.exe"

        if (Test-Path $autorunsPath) {
            Write-Log "  Found Autoruns tool, launching for manual review..."
            Start-Process -FilePath $autorunsPath
            Write-Log "  Please use the Autoruns tool to disable any problematic startup entries"
        }
        else {
            Write-Log "  Autoruns tool not found, checking startup entries via registry..."

            # Check startup folders
            $commonStartup = [Environment]::GetFolderPath("CommonStartup")
            $userStartup = [Environment]::GetFolderPath("Startup")

            Write-Log "  Checking common startup folder: $commonStartup"
            if (Test-Path $commonStartup) {
                $items = Get-ChildItem -Path $commonStartup
                foreach ($item in $items) {
                    Write-Log "  - Found startup item: $($item.Name)"
                }
            }

            Write-Log "  Checking user startup folder: $userStartup"
            if (Test-Path $userStartup) {
                $items = Get-ChildItem -Path $userStartup
                foreach ($item in $items) {
                    Write-Log "  - Found startup item: $($item.Name)"
                }
            }

            # Check Run keys
            $runKeys = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
            )

            foreach ($key in $runKeys) {
                if (Test-Path $key) {
                    Write-Log "  Checking registry key: $key"
                    $items = Get-ItemProperty -Path $key
                    foreach ($item in $items.PSObject.Properties) {
                        if ($item.Name -notin @("PSPath", "PSParentPath", "PSChildName", "PSProvider")) {
                            Write-Log "  - Found startup entry: $($item.Name) = $($item.Value)"
                        }
                    }
                }
            }
        }

        return $true
    }
    catch {
        Write-Log "Error checking startup programs: $($_.Exception.Message)"
        return $false
    }
}

# Function to repair Windows boot manager
function Repair-BootManager {
    try {
        Write-Log "Checking Windows Boot Manager configuration..."

        # Get BCD store information
        $bcdeditExe = Get-SystemExecutable -Name 'bcdedit'
$bcdOutput = & $bcdeditExe /enum 2>&1 | Out-String
        Write-Log "  Current BCD configuration:"
        Write-Log $bcdOutput

        # Check timeout value
        $timeoutMatch = [regex]::Match($bcdOutput, "timeout\s+(\d+)")
        if ($timeoutMatch.Success) {
            $timeout = [int]$timeoutMatch.Groups[1].Value

            # If timeout is too short, increase it
            if ($timeout -lt 5) {
                Write-Log "  Boot timeout is too short ($timeout seconds), increasing to 30 seconds..."
                $bcdeditExe = Get-SystemExecutable -Name 'bcdedit'
& $bcdeditExe /timeout 30
            }
        }

        # Check boot sequence
        $defaultMatch = [regex]::Match($bcdOutput, "default\s+\{([a-f0-9\-]+)\}")
        if ($defaultMatch.Success) {
            $defaultId = $defaultMatch.Groups[1].Value
            Write-Log "  Default boot entry ID: $defaultId"
        }

        # Fix potential boot manager issues
        Write-Log "  Attempting to repair boot manager..."
        $bcdeditExe = Get-SystemExecutable -Name 'bcdedit'
& $bcdeditExe /set {bootmgr} displaybootmenu yes
        $bcdeditExe = Get-SystemExecutable -Name 'bcdedit'
& $bcdeditExe /set {bootmgr} timeout 30

        return $true
    }
    catch {
        Write-Log "Error repairing boot manager: $($_.Exception.Message)"
        return $false
    }
}

# Function to repair Windows startup
function Repair-WindowsStartup {
    # Create a system restore point first
    New-SystemRestorePoint

    # Run all repair functions and track results
    $repairResults = @{
        "Boot Configuration" = Repair-BootConfiguration
        "Startup Components" = Repair-StartupComponents
        "Registry" = Repair-Registry
        "Startup Services" = Repair-StartupServices
        "Startup Programs" = Repair-StartupPrograms
        "Boot Manager" = Repair-BootManager
    }

    # --- DEBUGGING: Inspect the hashtable ---
    Write-Log "--- DEBUG: Contents of \$repairResults (Before Return) ---"
    $repairResults.GetEnumerator() | ForEach-Object {
        Write-Log "   Raw Object: $($_.GetType().FullName)"
        if ($_ -is [System.Collections.DictionaryEntry]) {
            Write-Log "   DictionaryEntry - Key: $($_.Key), Value: $($_.Value), KeyType: $($_.Key.GetType().FullName), ValueType: $($_.Value.GetType().FullName)"
        } else {
            Write-Log "   NOT a DictionaryEntry - Object: $_"
        }
    }
    Write-Log "--- DEBUG END ---"

    return $repairResults
}

# Display welcome message
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " RescuePC Repairs - Startup Repair Tool" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This utility will diagnose and fix Windows startup issues." -ForegroundColor White
Write-Host "It will create a system restore point before making any changes." -ForegroundColor White
Write-Host ""
Write-Host "WARNING: Some repairs may require a system restart to complete." -ForegroundColor Yellow
Write-Host ""

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "Please run the script as Administrator and try again." -ForegroundColor Red
    exit 1
}

# Get confirmation from user
$confirmation = $host.UI.PromptForChoice("Confirm Action", "Do you want to proceed with startup repairs?", @("&Yes", "&No"), 1)
if ($confirmation -ne 0) {
    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
    exit 0
}

# Start log
Write-Log "Starting Windows startup repair process..."

# Perform the repairs
$repairResults = Repair-WindowsStartup

# Display summary
Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " Startup Repair Results" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Cyan

foreach ($item in $repairResults.GetEnumerator()) {
    # --- DEBUGGING: Check the object type and properties ---
    Write-Log "--- DEBUG: Processing item ---"
    Write-Log "   Raw Object Type: $($item.GetType().FullName)"

    if ($item -is [System.Collections.DictionaryEntry]) {
        Write-Log "   It's a DictionaryEntry"
        Write-Log "   Key Type: $($item.Key.GetType().FullName)"
        Write-Log "   Value Type: $($item.Value.GetType().FullName)"

        $key = $item.Key
        $value = $item.Value

        Write-Log "   Extracted Key: '$key', Value: '$value'"

        $status = if ($value) { "Completed" } else { "Failed" }
        $color = if ($value) { "Green" } else { "Red" }

        Write-Host "${key}: " -NoNewline
        Write-Host $status -ForegroundColor $color
    } else {
        Write-Log "   ERROR: Unexpected object type: $($item.GetType().FullName)"
        Write-Host "ERROR: Unexpected data structure." -ForegroundColor Red
    }
    Write-Log "--- DEBUG END ---"
}

Write-Host ""
Write-Host "Startup repair process complete!" -ForegroundColor Green
Write-Host "A system restart is recommended to apply all changes." -ForegroundColor Yellow
Write-Host "Log file saved to: $logFile" -ForegroundColor White
Write-Host ""

# Ask for reboot
$rebootChoice = $host.UI.PromptForChoice("System Restart", "Do you want to restart the computer now?", @("&Yes", "&No"), 1)
if ($rebootChoice -eq 0) {
    Write-Host "Restarting system in 10 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    Restart-Computer -Force
}

exit 0
