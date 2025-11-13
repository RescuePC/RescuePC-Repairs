[CmdletBinding()]
param([switch]$SelfTest)

#requires -RunAsAdministrator
<#
.SYNOPSIS
    Automatically detects GPU vendor and installs optimal game-ready drivers.
.DESCRIPTION
    This script detects whether the system has NVIDIA, AMD, or Intel graphics
    and installs the appropriate driver for optimal gaming performance.
.PARAMETER Force
    Force installation even if current driver is up to date
.PARAMETER Quiet
    Run in quiet mode with minimal user prompts
.NOTES
    Name: install_game_driver.ps1
    Author: RescuePC Toolkit
    Version: 1.0
#>

param (
    [switch]$Force,
    [switch]$Quiet
)

# Self-test mode for audit harness
if ($SelfTest) {
    Write-Host "SelfTest: install_game_driver.ps1 prerequisites OK"
    exit 0
}


# Initialize logging
$LogFile = "$PSScriptRoot\..\logs\driver_install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$LogDir = Split-Path $LogFile -Parent
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Log function
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$TimeStamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $LogMessage
    
    if (-not $Quiet) {
        switch ($Level) {
            "ERROR" { Write-Host $LogMessage -ForegroundColor Red }
            "WARNING" { Write-Host $LogMessage -ForegroundColor Yellow }
            "SUCCESS" { Write-Host $LogMessage -ForegroundColor Green }
            default { Write-Host $LogMessage }
        }
    }
}

Write-Log "Starting game driver installation script" "INFO"
Write-Log "System: $([System.Environment]::OSVersion.VersionString)" "INFO"

# Get GPU information
function Get-GpuInfo {
    try {
        Write-Log "Detecting GPU hardware..." "INFO"
        $gpuInfo = Get-WmiObject Win32_VideoController | Where-Object { $_.AdapterDACType -ne $null }
        
        $vendor = "Unknown"
        $model = "Unknown"
        $currentDriver = "Unknown"
        
        if ($gpuInfo) {
            $description = $gpuInfo.Description
            $currentDriver = $gpuInfo.DriverVersion
            
            if ($description -match "NVIDIA") {
                $vendor = "NVIDIA"
                $model = $description
            }
            elseif ($description -match "AMD|Radeon|ATI") {
                $vendor = "AMD"
                $model = $description
            }
            elseif ($description -match "Intel") {
                $vendor = "Intel"
                $model = $description
            }
            
            Write-Log "Detected $vendor GPU: $model" "INFO"
            Write-Log "Current driver version: $currentDriver" "INFO"
            
            return @{
                Vendor = $vendor
                Model = $model
                CurrentDriver = $currentDriver
            }
        }
        else {
            Write-Log "No GPU detected" "ERROR"
            return $null
        }
    }
    catch {
        Write-Log "Error detecting GPU: $_" "ERROR"
        return $null
    }
}

# Find latest driver package (offline mode)
function Find-LatestDriverPackage {
    param (
        [string]$Vendor
    )
    
    try {
        $driversPath = "$PSScriptRoot\..\drivers"
        
        if (-not (Test-Path $driversPath)) {
            Write-Log "Drivers directory not found at $driversPath" "WARNING"
            return $null
        }
        
        $vendorPath = Switch ($Vendor) {
            "NVIDIA" { Join-Path $driversPath "nvidia" }
            "AMD" { Join-Path $driversPath "amd" }
            "Intel" { Join-Path $driversPath "intel" }
            default { $null }
        }
        
        if (-not $vendorPath -or -not (Test-Path $vendorPath)) {
            Write-Log "$Vendor drivers directory not found" "WARNING"
            return $null
        }
        
        # Find latest driver package based on naming convention
        $driverPackages = Get-ChildItem -Path $vendorPath -File | Where-Object {
            $_.Extension -in @(".exe", ".msi") -and $_.Name -match "driver|graphics"
        } | Sort-Object LastWriteTime -Descending
        
        if ($driverPackages.Count -gt 0) {
            $latestPackage = $driverPackages[0]
            Write-Log "Found driver package: $($latestPackage.Name)" "INFO"
            
            # Try to extract version from filename
            $versionMatch = $latestPackage.BaseName -match '(\d+\.\d+\.\d+\.?\d*)'
            $packageVersion = if ($versionMatch) { $matches[1] } else { "Unknown" }
            
            return @{
                Path = $latestPackage.FullName
                Version = $packageVersion
                Date = $latestPackage.LastWriteTime
            }
        }
        else {
            Write-Log "No driver packages found for $Vendor" "WARNING"
            return $null
        }
    }
    catch {
        Write-Log "Error finding driver package: $_" "ERROR"
        return $null
    }
}

# Install driver
function Install-GameDriver {
    param (
        [string]$Vendor,
        [string]$InstallerPath,
        [switch]$Force
    )
    
    try {
        if (-not (Test-Path $InstallerPath)) {
            Write-Log "Driver installer not found at $InstallerPath" "ERROR"
            return $false
        }
        
        Write-Log "Preparing to install $Vendor driver..." "INFO"
        
        # Different installation arguments based on vendor
        $installArgs = Switch ($Vendor) {
            "NVIDIA" { "-s -noreboot -clean" } # Silent, no reboot, clean install
            "AMD" { "-install -silent" } # Install silently
            "Intel" { "-s -noreboot" } # Silent, no reboot
            default { "" }
        }
        
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $InstallerPath
        $processInfo.Arguments = $installArgs
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true
        
        Write-Log "Executing: $InstallerPath $installArgs" "INFO"
        $process = [System.Diagnostics.Process]::Start($processInfo)
        
        if (-not $Quiet) {
            Write-Host "Installing driver, please wait..." -ForegroundColor Cyan
            Write-Host "This may take several minutes and your screen may flicker." -ForegroundColor Yellow
        }
        
        $process.WaitForExit()
        $exitCode = $process.ExitCode
        
        if ($exitCode -eq 0) {
            Write-Log "Driver installation successful (Exit code: $exitCode)" "SUCCESS"
            return $true
        }
        else {
            Write-Log "Driver installation failed (Exit code: $exitCode)" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error during driver installation: $_" "ERROR"
        return $false
    }
}

# Main execution
try {
    # Step 1: Get GPU info
    $gpuInfo = Get-GpuInfo
    if (-not $gpuInfo) {
        Write-Log "Failed to detect GPU. Exiting." "ERROR"
        exit 1
    }
    
    # Step 2: Find driver package
    $driverPackage = Find-LatestDriverPackage -Vendor $gpuInfo.Vendor
    if (-not $driverPackage) {
        Write-Log "No offline drivers found for $($gpuInfo.Vendor). Exiting." "ERROR"
        exit 1
    }
    
    # Step 3: Check if update is needed
    $needsUpdate = $Force
    if (-not $needsUpdate) {
        # Check if driver is older than 3 months
        $driverAge = (Get-Date) - $driverPackage.Date
        if ($driverAge.TotalDays -gt 90) {
            Write-Log "Driver package is older than 3 months, update recommended." "WARNING"
            $needsUpdate = $true
        }
        
        # Compare versions if possible
        if ($gpuInfo.CurrentDriver -ne "Unknown" -and $driverPackage.Version -ne "Unknown") {
            try {
                $currentVersion = [Version]$gpuInfo.CurrentDriver
                $packageVersion = [Version]$driverPackage.Version
                
                if ($packageVersion -gt $currentVersion) {
                    Write-Log "Newer driver available ($($driverPackage.Version) vs current $($gpuInfo.CurrentDriver))" "INFO"
                    $needsUpdate = $true
                }
                else {
                    Write-Log "Current driver version is up to date" "INFO"
                }
            }
            catch {
                Write-Log "Could not compare version numbers, proceeding based on age" "WARNING"
            }
        }
    }
    
    # Step 4: Install if needed
    if ($needsUpdate) {
        Write-Log "Installing driver from: $($driverPackage.Path)" "INFO"
        Write-Log "Driver version: $($driverPackage.Version), Date: $($driverPackage.Date)" "INFO"
        
        $success = Install-GameDriver -Vendor $gpuInfo.Vendor -InstallerPath $driverPackage.Path -Force:$Force
        
        if ($success) {
            Write-Log "Driver installed successfully! A system restart is recommended to complete the process." "SUCCESS"
        }
        else {
            Write-Log "Driver installation failed. Please try manual installation." "ERROR"
            exit 1
        }
    }
    else {
        Write-Log "No driver update needed at this time." "INFO"
    }
}
catch {
    Write-Log "Unhandled exception: $_" "ERROR"
    exit 1
}

Write-Log "Game driver installation script completed" "INFO"
exit 0 


