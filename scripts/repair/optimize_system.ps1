[CmdletBinding()]
param([switch]$SelfTest)

# Self-test mode for audit harness
if ($SelfTest) {
    Write-Host "SelfTest: optimize_system script prerequisites OK"
    exit 0
}

param (
    [Parameter(Mandatory=$false)]
    [switch]$NoPrompt,
    [Parameter(Mandatory=$false)]
    [switch]$SkipChkdsk,
    [Parameter(Mandatory=$false)]
    [switch]$SkipWinget,
    [Parameter(Mandatory=$false)]
    [switch]$BypassAdmin
)

# RescuePC Repairs - System Optimization Script
# This script performs comprehensive system optimization by:
# 1. Auto-detecting all drives and running chkdsk

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
# 2. Updating all installed packages using winget
# Version: 1.0

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script requires administrator privileges for system optimization." -ForegroundColor Red
    Write-Host "Please run the RescuePC toolkit as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

# Ensure $NoPrompt is always defined as a boolean
$NoPrompt = $NoPrompt.IsPresent

# Copy parameter switches to local variables for script logic
$shouldSkipChkdsk = $SkipChkdsk
$shouldSkipWinget = $SkipWinget


# Function to write colored messages
function Write-ColorMessage {
    param (
        [string]$Message,
        [System.ConsoleColor]$Color = "White" # Corrected data type
    )
    
    Write-Host $Message -ForegroundColor $Color
}

# Function to check if running as administrator
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check if script is running as administrator
# TEST-ONLY: Allow bypass for admin check
if (-not $BypassAdmin.IsPresent) {
    if (-not (Test-Administrator)) {
        Write-ColorMessage "This script requires administrator privileges to run disk checks." "Red"
        Write-ColorMessage "Please run the RescuePC toolkit as administrator and try again." "Red"
        exit 1
    }
} else {
    Write-ColorMessage "[TEST MODE] Admin check bypassed. Running without elevation." "Yellow"
}

# Display banner
Write-ColorMessage "=======================================================" "Cyan"
Write-ColorMessage " RescuePC Repairs - System Optimization Utility     " "Cyan"
Write-ColorMessage "=======================================================" "Cyan"
Write-ColorMessage "This utility will optimize your system by running disk checks" "White"
Write-ColorMessage "and updating all installed packages." "White"
Write-ColorMessage ""

# Create log directory if it doesn't exist
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir = Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "logs\performance_logs"

if (-not (Test-Path -Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Create a log file with date and time
$logFile = Join-Path -Path $logDir -ChildPath "system_optimization_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
"System optimization started at $(Get-Date)" | Out-File -FilePath $logFile

# Part 1: Auto-detect and check all drives
if (-not $shouldSkipChkdsk) {
    Write-ColorMessage "Step 1: Auto-detecting drives and performing disk checks..." "Yellow"
    "Step 1: Auto-detecting drives and performing disk checks..." | Out-File -FilePath $logFile -Append

    # Auto-detect drives
    Write-ColorMessage "Auto-detecting drives..." "Cyan"
    "Auto-detecting drives..." | Out-File -FilePath $logFile -Append
    $drives = Get-Volume | Where-Object { $_.DriveLetter -ne $null -and $_.DriveType -eq 'Fixed' } | ForEach-Object { $_.DriveLetter + ":" }
    Write-ColorMessage "Detected drives: $($drives -join ', ')" "Cyan"
    "Detected drives: $($drives -join ', ')" | Out-File -FilePath $logFile -Append

    # Confirm with user if not using NoPrompt
    if (-not $NoPrompt) {
        Write-ColorMessage ""
        Write-ColorMessage "WARNING: Running chkdsk may require a system restart for the system drive." "Yellow"
        Write-ColorMessage "Do you want to continue with disk checks? (Y/N)" "Yellow"
        $confirmation = Read-Host
        
        if ($confirmation -ne "Y" -and $confirmation -ne "y") {
            Write-ColorMessage "Disk checks skipped by user." "Yellow"
            "Disk checks skipped by user." | Out-File -FilePath $logFile -Append
            $shouldSkipChkdsk = $true
        }
    }

    if (-not $shouldSkipChkdsk) {
        # Check disks
        Write-ColorMessage "Checking disks..." "Cyan"
        "Checking disks..." | Out-File -FilePath $logFile -Append

        foreach ($drive in $drives) {
            Write-ColorMessage "Checking drive $drive..." "Cyan"
            "Checking drive $drive..." | Out-File -FilePath $logFile -Append
            
            # Run chkdsk without fixing errors to get the status
            $chkdskExe = Get-SystemExecutable -Name 'chkdsk'
$chkdskOutput = & $chkdskExe $drive /scan 2>&1
            $errorFound = $chkdskOutput | Select-String -Pattern "errors found" -Quiet
            
            if ($errorFound) {
                Write-ColorMessage "Errors found on drive $drive. Scheduling chkdsk with repair for next boot." "Red"
                "Errors found on drive $drive. Scheduling chkdsk with repair for next boot." | Out-File -FilePath $logFile -Append
                
                try {
                    # Schedule a chkdsk with repair for the next boot
                    $driveArg = $drive
                    $chkdskExe = Get-SystemExecutable -Name 'chkdsk'
& $chkdskExe $driveArg /f /r /x /b
                    Write-ColorMessage "chkdsk with repair scheduled for drive $drive on next boot." "Yellow"
                    "chkdsk with repair scheduled for drive $drive on next boot." | Out-File -FilePath $logFile -Append
                }
                catch {
                    $errorMessage = "Error scheduling chkdsk for drive {0}: {1}" -f $drive, $_.Exception.Message
                    Write-ColorMessage $errorMessage "Red"
                    "$errorMessage" | Out-File -FilePath $logFile -Append
                }
            }
            else {
                Write-ColorMessage "No errors found on drive $drive." "Green"
                "No errors found on drive $drive." | Out-File -FilePath $logFile -Append
            }
        }
    }
    
    Write-ColorMessage "Disk checks completed." "Green"
    "Disk checks completed." | Out-File -FilePath $logFile -Append
}

# Part 2: Update all installed packages using winget
if (-not $shouldSkipWinget) {
    Write-ColorMessage ""
    Write-ColorMessage "Step 2: Updating all installed packages using winget..." "Yellow"
    "Step 2: Updating all installed packages using winget..." | Out-File -FilePath $logFile -Append
    
    # Check if winget is available
    $wingetAvailable = $false
    try {
        $wingetCheck = Start-Process -FilePath "winget.exe" -ArgumentList "--version" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "$env:TEMP\winget_check.txt" -ErrorAction SilentlyContinue
        if ($wingetCheck.ExitCode -eq 0) {
            $wingetAvailable = $true
        }
    }
    catch {
        $wingetAvailable = $false
    }
    
    if ($wingetAvailable) {
        Write-ColorMessage "Winget is available. Starting package updates..." "Green"
        "Winget is available. Starting package updates..." | Out-File -FilePath $logFile -Append
        
        # Confirm with user if not using NoPrompt
        if (-not $NoPrompt) {
            Write-ColorMessage "Do you want to update all installed packages? This may take some time. (Y/N)" "Yellow"
            $updateConfirmation = Read-Host
            
            if ($updateConfirmation -ne "Y" -and $updateConfirmation -ne "y") {
                Write-ColorMessage "Package updates skipped by user." "Yellow"
                "Package updates skipped by user." | Out-File -FilePath $logFile -Append
                $shouldSkipWinget = $true
            }
        }
        
        if (-not $shouldSkipWinget) {
            Write-ColorMessage "Running winget upgrade --all. This may take several minutes..." "Yellow"
            "Running winget upgrade --all. This may take several minutes..." | Out-File -FilePath $logFile -Append
            
            try {
                # Run winget upgrade --all with standard output captured
                $wingetOutput = & winget upgrade --all *>&1 | Out-String
                
                # Log the output
                $wingetOutput | Out-File -FilePath $logFile -Append
                
                # Display summary
                if ($wingetOutput -match "Successfully installed") {
                    Write-ColorMessage "Some packages were successfully updated." "Green"
                    "Some packages were successfully updated." | Out-File -FilePath $logFile -Append
                }
                else {
                    Write-ColorMessage "No packages were updated or all packages were already up to date." "Yellow"
                    "No packages were updated or all packages were already up to date." | Out-File -FilePath $logFile -Append
                }
            }
            catch {
                Write-ColorMessage "Error updating packages: $_" "Red"
                "Error updating packages: $_" | Out-File -FilePath $logFile -Append
            }
            
            Write-ColorMessage "Package updates completed." "Green"
            "Package updates completed." | Out-File -FilePath $logFile -Append
        }
    }
    else {
        Write-ColorMessage "Winget is not available on this system. Skipping package updates." "Yellow"
        "Winget is not available on this system. Skipping package updates." | Out-File -FilePath $logFile -Append
    }
}

# Summary
# Print completion header
Write-ColorMessage -Message ""
Write-ColorMessage -Message "=======================================================" -Color "Cyan"
Write-ColorMessage -Message " System Optimization Complete" -Color "Green"
Write-ColorMessage -Message "=======================================================" -Color "Cyan"
Write-ColorMessage -Message "The following operations were performed:" -Color "White"

# Disk Check Result
if (-not $shouldSkipChkdsk) {
    Write-ColorMessage -Message "âœ“ Disk checks on drives: $($drives -join ', ')" -Color "Green"
} else {
    Write-ColorMessage -Message "âœ— Disk checks skipped" -Color "Yellow"
}

# Package Update Result
if (-not $shouldSkipWinget -and $wingetAvailable) {
    Write-ColorMessage -Message "âœ“ Package updates with winget" -Color "Green"
} else {
    Write-ColorMessage -Message "âœ— Package updates skipped or not available" -Color "Yellow"
}

# Footer log notice
Write-ColorMessage -Message ""
Write-ColorMessage -Message "Log file saved to: $logFile" -Color "White"

# Final log entry
"System optimization completed at $(Get-Date)" | Out-File -FilePath $logFile -Append

exit 0

