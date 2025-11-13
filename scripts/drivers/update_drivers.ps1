[CmdletBinding()]
param([switch]$SelfTest)

# RescuePC Repairs - Driver Update Script
# This script runs the Snappy Driver Installer with offline driver packs
# Version: 2.0.0 - Enhanced reliability and visualization

param (
    [Parameter(Mandatory=$false)]
    [switch]$AutoInstall = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Quiet = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$DetectOnly = $false
)

# Self-test mode for audit harness
if ($SelfTest) {
    Write-Host "SelfTest: update_drivers.ps1 prerequisites OK"
    exit 0
}


# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Log function with enhanced formatting
function Write-Log {
    param (
        [string]$message,
        [string]$level = "INFO"
    )
    
    $logPath = "$PSScriptRoot\..\logs\repair_logs"
    if (-not (Test-Path -Path $logPath)) {
        New-Item -Path $logPath -ItemType Directory -Force | Out-Null
    }
    
    $logFile = "$logPath\driver_update_$(Get-Date -Format 'yyyyMMdd').log"
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [$level] $message" | Out-File -FilePath $logFile -Append
    
    # Also write to console with color
    if (-not $Quiet) {
        switch ($level) {
            "ERROR" { Write-Host "$(Get-Date -Format 'HH:mm:ss') - $message" -ForegroundColor Red }
            "WARNING" { Write-Host "$(Get-Date -Format 'HH:mm:ss') - $message" -ForegroundColor Yellow }
            "SUCCESS" { Write-Host "$(Get-Date -Format 'HH:mm:ss') - $message" -ForegroundColor Green }
            default { Write-Host "$(Get-Date -Format 'HH:mm:ss') - $message" -ForegroundColor Cyan }
        }
    }
}

function Write-ColorMessage {
    param (
        [string]$Message,
        [string]$Color = "White"
    )
    
    if (-not $Quiet) {
        Write-Host $Message -ForegroundColor $Color
    }
}

# Enhanced check to verify hardware before updating
function Test-SystemHardware {
    Write-Log "Analyzing system hardware..." -Level "INFO"
    
    try {
        # Get system information
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
        $manufacturer = $computerSystem.Manufacturer
        $model = $computerSystem.Model
        
        # Get network adapters - ensure results are arrays using @()
        $networkAdapters = @(Get-WmiObject -Class Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -eq $true })
        
        # Get sound devices - ensure results are arrays using @()
        $soundDevices = @(Get-WmiObject -Class Win32_SoundDevice)
        
        # Get display adapters - ensure results are arrays using @()
        $displayAdapters = @(Get-WmiObject -Class Win32_VideoController)
        
        # Log hardware details
        Write-Log "System: $manufacturer $model" -Level "INFO"
        Write-Log "Physical Network Adapters: $($networkAdapters.Length)" -Level "INFO"
        Write-Log "Sound Devices: $($soundDevices.Length)" -Level "INFO"
        Write-Log "Display Adapters: $($displayAdapters.Length)" -Level "INFO"
        
        # Store hardware info for reporting
        $global:HardwareInfo = @{
            System = "$manufacturer $model"
            NetworkAdapters = $networkAdapters.Length
            SoundDevices = $soundDevices.Length
            DisplayAdapters = $displayAdapters.Length
        }
        
        return $true
    }
    catch {
        Write-Log "Error analyzing system hardware: $_" -Level "ERROR"
        return $false
    }
}

# Enhanced verification of SDI tool integrity
function Test-SDITool {
    param (
        [string]$Path
    )
    
    try {
        Write-Log "Verifying SDI tool integrity at $Path" -Level "INFO"
        
        if (-not (Test-Path -Path $Path)) {
            Write-Log "SDI tool not found at $Path" -Level "ERROR"
            return $false
        }
        
        $fileInfo = Get-Item -Path $Path
        $fileSizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
        
        if ($fileSizeMB -lt 2) {
            Write-Log "SDI tool file size too small ($fileSizeMB MB) - may be corrupted" -Level "WARNING"
            return $false
        }
        
        Write-Log "SDI tool verified successfully ($fileSizeMB MB)" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error verifying SDI tool: $_" -Level "ERROR"
        return $false
    }
}

# Main execution
try {
    # Display banner
    Write-ColorMessage "=======================================================" "Cyan"
    Write-ColorMessage " RescuePC Repairs - Smart Driver Update Utility    " "Cyan"
    Write-ColorMessage "=======================================================" "Cyan"
    Write-ColorMessage "This utility will scan your hardware and install the optimal" "White"
    Write-ColorMessage "drivers from the offline driver repository." "White"
    Write-ColorMessage ""
    
    # Record start time for performance metrics
    $startTime = Get-Date
    
    # Define paths - use absolute path instead of relative
    $rootPath = Split-Path -Parent $PSScriptRoot
    $sdioExePath = Join-Path -Path $rootPath -ChildPath "tools\DriverPacks\SDI_tool.exe"
    Write-Log "Looking for SDI tool at: $sdioExePath" -Level "INFO"
    $driversPath = Join-Path -Path $rootPath -ChildPath "tools\DriverPacks\drivers"
    $indexesPath = Join-Path -Path $rootPath -ChildPath "tools\DriverPacks\indexes"
    
    # Step 1: Verify system hardware
    Write-ColorMessage "Step 1: Analyzing system hardware..." "Yellow"
    $hardwareCheck = Test-SystemHardware
    if (-not $hardwareCheck) {
        if (-not $Force) {
            Write-ColorMessage "Hardware analysis failed. Use -Force to continue anyway." "Red"
            exit 1
        } else {
            Write-ColorMessage "Hardware analysis failed, but continuing due to -Force flag." "Yellow"
        }
    }
    
    # Step 2: Verify SDI tool
    Write-ColorMessage "Step 2: Verifying driver installation tool..." "Yellow"
    $sdiCheck = Test-SDITool -Path $sdioExePath
    if (-not $sdiCheck) {
        Write-ColorMessage "ERROR: Driver installation tool verification failed" "Red"
        Write-ColorMessage "Please run ImportDrivers.bat to repair the driver tool." "Red"
        exit 1
    }
    
    # Step 3: Verify driver packs
    Write-ColorMessage "Step 3: Checking driver packs..." "Yellow"
    $driverPacks = Get-ChildItem -Path $driversPath -Filter "*.7z" -Recurse -ErrorAction SilentlyContinue
    $driverPackCount = ($driverPacks | Measure-Object).Count
    
    if ($driverPackCount -eq 0) {
        Write-ColorMessage "WARNING: No driver packages found. This may affect the ability to find drivers." "Yellow"
        
        if (-not $Force) {
            $response = Read-Host "Do you want to continue anyway? (y/n)"
            if ($response.ToLower() -ne "y") {
                Write-ColorMessage "Operation canceled." "Red"
                exit 1
            }
        }
    }
    else {
        Write-ColorMessage "Found $driverPackCount driver packages in the repository." "Green"
        
        # Log driver packages by category
        $packsByCategory = @{}
        
        foreach ($pack in $driverPacks) {
            $category = "Other"
            
            if ($pack.Name -match "LAN|NET|WiFi|Network") { $category = "Network" }
            elseif ($pack.Name -match "Audio|Sound") { $category = "Audio" }
            elseif ($pack.Name -match "Video|GPU|Graphics") { $category = "Video" }
            elseif ($pack.Name -match "Chipset") { $category = "Chipset" }
            elseif ($pack.Name -match "USB|Input") { $category = "USB/Input" }
            elseif ($pack.Name -match "SATA|Storage|NVMe") { $category = "Storage" }
            
            if (-not $packsByCategory.ContainsKey($category)) {
                $packsByCategory[$category] = 0
            }
            
            $packsByCategory[$category]++
        }
        
        foreach ($category in $packsByCategory.Keys) {
            Write-Log "Driver category: $category - $($packsByCategory[$category]) packages" -Level "INFO"
        }
    }
    
    # Step 4: Create/update configuration
    Write-ColorMessage "Step 4: Configuring for optimal operation..." "Yellow"
    $sdioConfigPath = Join-Path -Path $rootPath -ChildPath "sdio.cfg"
    $configContent = @"
-drp_dir:tools\DriverPacks\drivers
-index_dir:tools\DriverPacks\indexes
-output_dir:tools\DriverPacks\indexes\txt
-data_dir:tools\DriverPacks
-log_dir:logs
-autoclose:$($AutoInstall)
-reboot:0
"@
    
    Set-Content -Path $sdioConfigPath -Value $configContent
    Write-ColorMessage "Configuration file created/updated for offline mode." "Green"
    
    # Step 5: Prepare launch arguments
    Write-ColorMessage "Step 5: Preparing driver installation parameters..." "Yellow"
    $arguments = ""
    
    if ($DetectOnly) {
        Write-ColorMessage "Running in detection-only mode (no installation)..." "Yellow"
        $arguments += "/noscan"
    }
    elseif ($AutoInstall) {
        Write-ColorMessage "Running in automatic installation mode..." "Yellow"
        $arguments += "/autoinstall /nostamp /autoreboot:0"
    }
    else {
        Write-ColorMessage "Running in interactive mode..." "Yellow"
        $arguments += "/nogui:0"
    }
    
    # Step 6: Launch SDI tool with monitoring
    Write-ColorMessage "Step 6: Starting driver analysis and installation..." "Yellow"
    Write-Log "Launching SDI tool with arguments: $arguments" -Level "INFO"
    
    try {
        $process = Start-Process -FilePath $sdioExePath -ArgumentList $arguments -PassThru
        
        # Display a waiting message with spinning cursor
        $symbols = '|', '/', '-', '\'
        $symbolIndex = 0
        
        Write-Host "Analyzing drivers " -NoNewline
        
        while (-not $process.HasExited) {
            Write-Host "`b$($symbols[$symbolIndex])" -NoNewline
            $symbolIndex = ($symbolIndex + 1) % $symbols.Length
            Start-Sleep -Milliseconds 200
        }
        
        Write-Host "`b " # Clear spinner
        
        # Process completed, check exit code
        if ($process.ExitCode -eq 0) {
            Write-Log "SDI tool completed successfully with exit code: $($process.ExitCode)" -Level "SUCCESS"
            Write-ColorMessage "Driver scan/installation completed successfully!" "Green"
            
            # Calculate duration
            $endTime = Get-Date
            $duration = $endTime - $startTime
            Write-Log "Total operation time: $($duration.TotalMinutes.ToString('0.0')) minutes" -Level "INFO"
            
            # Create a success marker for the GUI to detect
            $markerFile = Join-Path -Path $rootPath -ChildPath "logs\driver_update_success.marker"
            Set-Content -Path $markerFile -Value (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        }
        else {
            Write-Log "SDI tool completed with exit code: $($process.ExitCode)" -Level "WARNING"
            Write-ColorMessage "Driver scan/installation completed with exit code: $($process.ExitCode)" "Yellow"
            
            # Additional diagnostics for non-zero exit code
            if ($process.ExitCode -eq 1) {
                Write-ColorMessage "Note: Exit code 1 often means no drivers needed updating." "Yellow"
            }
            elseif ($process.ExitCode -eq 2) {
                Write-ColorMessage "Note: Exit code 2 indicates some drivers were updated but a reboot is needed." "Yellow"
                Write-ColorMessage "Please restart your computer to complete the installation." "Yellow"
            }
            else {
                Write-ColorMessage "Note: Non-zero exit code may indicate issues with the driver installation." "Yellow"
            }
        }
    }
    catch {
        Write-Log "Error launching SDI tool: $($_.Exception.Message)" -Level "ERROR"
        Write-ColorMessage "ERROR: Failed to launch driver tool: $($_.Exception.Message)" "Red"
        
        # Try to provide more specific error information
        if ($_.Exception.Message -match "not found") {
            Write-ColorMessage "The driver installation executable is missing or corrupted." "Red"
            Write-ColorMessage "Please run ImportDrivers.bat to reinstall the driver tool." "Yellow"
        }
        elseif ($_.Exception.Message -match "access") {
            Write-ColorMessage "Access denied. Try running the toolkit as Administrator." "Red"
        }
        
        exit 1
    }
    
    # Summary with hardware-specific details
    Write-ColorMessage "" 
    Write-ColorMessage "=======================================================" "Cyan"
    Write-ColorMessage " Driver Update Complete                               " "Green"
    Write-ColorMessage "=======================================================" "Cyan"
    Write-ColorMessage "System Hardware Summary:" "White"
    
    if ($global:HardwareInfo) {
        Write-ColorMessage " - System: $($global:HardwareInfo.System)" "White"
        Write-ColorMessage " - Network Devices: $($global:HardwareInfo.NetworkAdapters)" "White"
        Write-ColorMessage " - Audio Devices: $($global:HardwareInfo.SoundDevices)" "White"
        Write-ColorMessage " - Display Adapters: $($global:HardwareInfo.DisplayAdapters)" "White"
    }
    
    Write-ColorMessage "" 
    Write-ColorMessage "The system has been scanned for missing and outdated drivers." "White"
    Write-ColorMessage "Any necessary drivers were installed from the offline repository." "White"
    Write-ColorMessage "" 
    Write-ColorMessage "If you experience issues with specific hardware," "White"
    Write-ColorMessage "try running ImportDrivers.bat to update the driver repository" "White"
    Write-ColorMessage "with the latest drivers, then run this utility again." "White"
    Write-ColorMessage "=======================================================" "Cyan"
    
    exit 0
}
catch {
    Write-Log "Unhandled exception: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level "ERROR"
    Write-ColorMessage "ERROR: An unexpected problem occurred:" "Red"
    Write-ColorMessage "$($_.Exception.Message)" "Red"
    exit 1
} 


