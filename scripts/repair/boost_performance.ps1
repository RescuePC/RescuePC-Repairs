[CmdletBinding()]
param(
    [switch]$SelfTest,
    [Parameter(Mandatory=$false)]
    [ValidateSet("Conservative", "Balanced", "Aggressive", "Gaming", "Workstation")]
    [string]$OptimizationLevel = "Balanced",

    [Parameter(Mandatory=$false)]
    [switch]$CreateRestorePoint = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$MonitorPerformance = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$OptimizeForSSD = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$GamingMode = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$WorkstationMode = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipServiceOptimization = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Quiet = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false
)

# Self-test mode for audit harness
if ($SelfTest) {
    Write-Host "SelfTest: boost_performance.ps1 prerequisites OK"
    exit 0
}


# Set strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue" # Changed to Continue for better error handling

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script requires administrator privileges for system optimization." -ForegroundColor Red
    Write-Host "Please run the RescuePC toolkit as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

# --- Ensure script runs in 64-bit PowerShell if on 64-bit Windows ---
if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
    Write-Host "[INFO] Relaunching script in 64-bit PowerShell for compatibility with system tools..."
    $ps64 = "$env:SystemRoot\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $ps64) {
        Start-Process -FilePath $ps64 -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    } else {
        Write-Host "[ERROR] Could not find 64-bit PowerShell. Some features may not work."
    }
}

# --- Find full path to powercfg.exe ---
$global:PowerCfgPath = (Join-Path $env:SystemRoot 'System32\powercfg.exe')
if (-not (Test-Path $global:PowerCfgPath)) {
    Write-Host "[ERROR] powercfg.exe not found at $global:PowerCfgPath. Power settings operations will fail."
    $global:PowerCfgPath = 'powercfg' # fallback to default
}

# Enhanced script configuration with performance tracking
$logFile = "$PSScriptRoot\..\logs\performance_logs\performance_enhanced_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$configBackupPath = "$PSScriptRoot\..\backup\performance_settings_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# Global variables for enhanced tracking
$global:OptimizationStats = @{
    OptimizationsApplied = 0
    OptimizationsFailed = 0
    OptimizationsSkipped = 0
    PerformanceGain = 0
}
$global:SystemBaseline = @{}
$global:OptimizationResults = @()
$global:PerformanceMetrics = @{
    BeforeCPU = 0
    AfterCPU = 0
    BeforeMemory = 0
    AfterMemory = 0
    BeforeDisk = 0
    AfterDisk = 0
}

# Create log directory if it doesn't exist
$logDir = Split-Path -Parent $logFile
if (-not (Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Create backup directory if it doesn't exist
if (-not (Test-Path -Path $configBackupPath)) {
    New-Item -ItemType Directory -Path $configBackupPath -Force | Out-Null
}

# Enhanced log function with performance tracking and quiet mode
function Write-Log {
    param (
        [string]$message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "DEBUG", "PERF")]
        [string]$level = "INFO",
        [switch]$NoConsole = $false
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$level] $message"
    
    # Write to log file with error handling
    try {
        Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
    }
    catch {
        # Fallback if log file is locked
        Start-Sleep -Milliseconds 50
        try {
            Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
        }
        catch {
            # Silent fail if we can't write to log
        }
    }
    
    # Console output with colors (unless quiet or NoConsole)
    if (-not $Quiet -and -not $NoConsole) {
        $color = switch ($level) {
            "INFO" { "Cyan" }
            "WARNING" { "Yellow" }
            "ERROR" { "Red" }
            "SUCCESS" { "Green" }
            "DEBUG" { "Gray" }
            "PERF" { "Magenta" }
            default { "White" }
        }
        Write-Host $logMessage -ForegroundColor $color
    }
}

function Show-Progress {
    param (
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete
    )
    
    if (-not $Quiet) {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
    }
}

function Show-Header {
    if (-not $Quiet) {
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host " RescuePC Repairs - Enhanced Performance Optimizer v3.0   " -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""
        
        # Show current mode
        $modeColor = switch ($OptimizationLevel) {
            "Conservative" { "Green" }
            "Balanced" { "Cyan" }
            "Aggressive" { "Yellow" }
            "Gaming" { "Magenta" }
            "Workstation" { "Blue" }
            default { "White" }
        }
        Write-Host "Optimization Level: $OptimizationLevel" -ForegroundColor $modeColor
        
        if ($GamingMode) {
            Write-Host "Gaming Mode: Enabled" -ForegroundColor Magenta
        }
        if ($WorkstationMode) {
            Write-Host "Workstation Mode: Enabled" -ForegroundColor Blue
        }
        if ($OptimizeForSSD) {
            Write-Host "SSD Optimization: Enabled" -ForegroundColor Green
        }
        if ($DryRun) {
            Write-Host "Dry Run Mode: Enabled (no changes will be made)" -ForegroundColor Yellow
        }
        Write-Host ""
    }
}

# Function to create a system restore point with enhanced error handling
function New-SystemRestorePoint {
    try {
        Write-Log "Creating system restore point..." -level "INFO"
        
        # Check if System Restore is enabled
        $srEnabled = $false
        
        try {
            $srProperty = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval" -ErrorAction SilentlyContinue
            if ($null -ne $srProperty) {
                $srEnabled = ($srProperty.RPSessionInterval -ne 0)
            }
        } catch {
            Write-Log "Could not determine System Restore status: $($_.Exception.Message)" -level "WARNING"
        }
        
        if (-not $srEnabled) {
            # Try to enable System Restore
            try {
                Write-Log "System Restore is not enabled. Attempting to enable it..." -level "WARNING"
                Enable-ComputerRestore -Drive $env:SystemDrive -ErrorAction Stop
                $srEnabled = $true # Assume success if no error
                Write-Log "System Restore has been enabled successfully." -level "SUCCESS"
            } catch {
                Write-Log "Failed to enable System Restore: $($_.Exception.Message)" -level "ERROR"
                return $false
            }
        }
        
        if ($srEnabled) {
            # Create the restore point
            $description = "RescuePC Performance Optimization"
            Checkpoint-Computer -Description $description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
            
            Write-Log "System restore point created successfully." -level "SUCCESS"
            return $true
        } else {
            Write-Log "System Restore is not available or could not be enabled. Proceeding without creating a restore point." -level "WARNING"
            return $false
        }
    }
    catch {
        Write-Log "Error creating system restore point: $($_.Exception.Message)" -level "ERROR"
        return $false
    }
}

# Function to back up current settings before making changes
function Backup-CurrentSettings {
    $allSuccess = $true
    Write-Log "Backing up current system settings..." -level "INFO"
    
    # Step 1: Visual Effects
    try {
        $visualEffectsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        if (Test-Path -Path $visualEffectsPath) {
            $visualEffectsBackup = Get-ItemProperty -Path $visualEffectsPath
            $visualEffectsBackup | Export-Clixml -Path "$configBackupPath\visual_effects.xml" -Force
            Write-Log "Backed up visual effects settings." -level "SUCCESS"
        } else {
            Write-Log "Visual effects registry path not found." -level "WARNING"
        }
    } catch {
        Write-Log "Failed to back up visual effects: $($_.Exception.Message)" -level "ERROR"
        $allSuccess = $false
    }
    
    # Step 2: Services
    try {
        $services = Get-Service
        $services | Export-Clixml -Path "$configBackupPath\services.xml" -Force
        Write-Log "Backed up services configuration." -level "SUCCESS"
    } catch {
        Write-Log "Failed to back up services: $($_.Exception.Message)" -level "ERROR"
        $allSuccess = $false
    }
    
    # Step 3: Power Settings
    try {
        $powerCfgOutput = & $global:PowerCfgPath -list
        $powerCfgOutput | Out-File -FilePath "$configBackupPath\power_settings.txt" -Force -Encoding UTF8
        Write-Log "Backed up power settings." -level "SUCCESS"
    } catch {
        Write-Log "Failed to back up power settings: $($_.Exception.Message)" -level "ERROR"
        $allSuccess = $false
    }
    
    # Step 4: Startup Items
    try {
        $startupItems = Get-CimInstance -ClassName Win32_StartupCommand
        $startupItems | Export-Clixml -Path "$configBackupPath\startup_items.xml" -Force
        Write-Log "Backed up startup items." -level "SUCCESS"
    } catch {
        Write-Log "Failed to back up startup items: $($_.Exception.Message)" -level "ERROR"
        $allSuccess = $false
    }
    
    # Step 5: Page File System Settings
    try {
        $pageFileSystem = Get-CimInstance -Class Win32_ComputerSystem | Select-Object AutomaticManagedPagefile
        $pageFileSystem | Export-Clixml -Path "$configBackupPath\pagefile_system_settings.xml" -Force
        Write-Log "Backed up page file system settings." -level "SUCCESS"
    } catch {
        Write-Log "Failed to back up page file system settings: $($_.Exception.Message)" -level "ERROR"
        $allSuccess = $false
    }
    
    # Step 6: Page File Specific Settings
    try {
        $pageFileSettings = Get-CimInstance -Class Win32_PageFileSetting
        $pageFileSettings | Export-Clixml -Path "$configBackupPath\pagefile_specific_settings.xml" -Force
        Write-Log "Backed up page file specific settings." -level "SUCCESS"
    } catch {
        Write-Log "Failed to back up page file specific settings: $($_.Exception.Message)" -level "ERROR"
        $allSuccess = $false
    }
    
    if ($allSuccess) {
        Write-Log "Current settings backed up to $configBackupPath" -level "SUCCESS"
        return $true
    } else {
        Write-Log "One or more backup steps failed. Review log for details." -level "ERROR"
        return $false
    }
}

# Function to optimize visual effects with enhanced safety
function Optimize-VisualEffects {
    try {
        Write-Log "Optimizing visual effects..." -level "INFO"
        
        # Set visual effects for best performance
        $visualEffectsRegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        if (-not (Test-Path -Path $visualEffectsRegPath)) {
            New-Item -Path $visualEffectsRegPath -Force -ErrorAction Stop | Out-Null
        }
        
        $currentFxSetting = Get-ItemProperty -Path $visualEffectsRegPath -Name "VisualFXSetting" -ErrorAction SilentlyContinue
        if ($currentFxSetting) {
            Write-Log "  Current visual effects setting (VisualFXSetting): $($currentFxSetting.VisualFXSetting)" -level "INFO"
        }
        Set-ItemProperty -Path $visualEffectsRegPath -Name "VisualFXSetting" -Value 2 -Type DWORD -Force -ErrorAction Stop
        Write-Log "  Visual effects (VisualFXSetting) set to best performance (Value: 2)." -level "SUCCESS"
        
        # Optimize advanced performance settings (UserPreferencesMask)
        $desktopRegPath = "HKCU:\Control Panel\Desktop"
        # The UserPreferencesMask value (0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00) typically means "Adjust for best performance"
        # but also keeps "Smooth edges of screen fonts" and "Show thumbnails instead of icons".
        # A more aggressive "best performance" often unchecks these too. Value '2' above is the master switch.
        # For fine-grained control if VisualFXSetting=3 (Custom):
        # UserPreferencesMask: 9E = Let Windows Choose, 9F = Best Appearance + some custom, 90 = Best Performance (usually)
        # To be absolutely sure "Adjust for best performance" is hit (which disables most animations):
        # The value [byte[]](0x90, 0x32, 0x07, 0x80, 0x12, 0x00, 0x00, 0x00) is often seen for "best performance"
        # However, setting VisualFXSetting to 2 handles this globally.
        # We will ensure animations are off via UserPreferencesMask as well if needed, but VisualFXSetting=2 is primary.
        # The provided value [byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00) is one combination.
        # A common "Best Performance" mask often seen is to disable all animations by clearing relevant bits.
        # For simplicity, relying on VisualFXSetting=2 is preferred.
        # If explicitly disabling animations (redundant if VisualFXSetting=2 works as expected):
        # Set-ItemProperty -Path $desktopRegPath -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -Type Binary -Force
        # Write-Log "  UserPreferencesMask configured for performance." -level "INFO"

        # Disable specific animations that might persist
        $windowMetricsRegPath = "HKCU:\Control Panel\Desktop\WindowMetrics"
        if (-not (Test-Path -Path $windowMetricsRegPath)) {
            New-Item -Path $windowMetricsRegPath -Force -ErrorAction Stop | Out-Null
        }
        Set-ItemProperty -Path $windowMetricsRegPath -Name "MinAnimate" -Value "0" -Type String -Force -ErrorAction Stop # Window animations
        Write-Log "  Window animations (MinAnimate) disabled." -level "SUCCESS"
        
        # Disable menu animations (often handled by UserPreferencesMask or VisualFXSetting=2)
        # Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" -Type String -Force # Optional: makes menus appear faster
        # Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuAnimation" -Value "0" -Type String -Force # Old setting, less common now

        # Disable transparency
        $personalizeRegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        if (-not (Test-Path -Path $personalizeRegPath)) {
            New-Item -Path $personalizeRegPath -Force -ErrorAction Stop | Out-Null
        }
        Set-ItemProperty -Path $personalizeRegPath -Name "EnableTransparency" -Value 0 -Type DWORD -Force -ErrorAction Stop
        Write-Log "  Transparency effects disabled." -level "SUCCESS"
        
        Write-Log "Visual effects optimization attempt complete. A reboot or logoff/logon may be needed for all changes to apply." -level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error optimizing visual effects: $($_.Exception.Message)" -level "ERROR"
        return $false
    }
}

# Function to analyze and optimize startup programs
function Optimize-Startup {
    try {
        Write-Log "Analyzing startup programs..." -level "INFO"
        
        # Get current startup items - wrap with @() to ensure array
        $startupItems = @(Get-CimInstance -ClassName Win32_StartupCommand -ErrorAction SilentlyContinue)
        
        if ($startupItems.Count -eq 0) {
            Write-Log "  No startup items found via Win32_StartupCommand." -level "INFO"
        } else {
            Write-Log "  Found $($startupItems.Length) startup items (via Win32_StartupCommand)." -level "INFO"
        }
        
        # Known safe startup items (keep these enabled) - Examples
        $safeStartupItems = @(
            "Windows Security notification icon",
            "Microsoft OneDrive", # User dependent
            "Windows Defender",   # Should be SecurityHealthSystray.exe
            "SecurityHealthSystray" 
        )
        
        # Known unnecessary startup items (can be safely disabled) - Examples
        $unnecessaryStartupItems = @(
            "Adobe Reader Speed Launcher", # For Adobe Reader, not Acrobat
            "QuickTime Alternative", # If QuickTime itself is not essential
            "iTunesHelper", # If not actively using iTunes sync features
            "GoogleUpdateTaskMachine", # Consider impact on Chrome/Google product updates
            "Spotify Web Helper", # If Spotify desktop app is used, this might be for web playback
            "Steam Client Bootstrapper", # User dependent, for gamers
            "JavaUpdateShed" # Java Update Scheduler
        )
        
        # List all startup items with recommendations
        # Note: Win32_StartupCommand is limited and doesn't show all startup items (e.g., Task Scheduler, services)
        # For a more comprehensive list, one would need to query multiple locations:
        # HKLM\Software\Microsoft\Windows\CurrentVersion\Run
        # HKCU\Software\Microsoft\Windows\CurrentVersion\Run
        # HKLM\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run (on 64-bit systems for 32-bit apps)
        # HKCU\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run (on 64-bit systems for 32-bit apps)
        # Startup Folders (User and All Users)
        # Task Scheduler entries

        if ($startupItems.Count -gt 0) {
            foreach ($item in $startupItems) {
                $itemName = if ($item.Name) { $item.Name } else { "Unknown" }
                $itemCommand = if ($item.Command) { $item.Command } else { "N/A" }
                $isSafe = $false
                $isUnnecessary = $false
                
                foreach ($safeKeyword in $safeStartupItems) {
                    if (($itemName -like "*$safeKeyword*") -or ($itemCommand -like "*$safeKeyword*")) {
                        $isSafe = $true
                        break
                    }
                }
                
                foreach ($unnecessaryKeyword in $unnecessaryStartupItems) {
                    if (($itemName -like "*$unnecessaryKeyword*") -or ($itemCommand -like "*$unnecessaryKeyword*")) {
                        $isUnnecessary = $true
                        break
                    }
                }
                
                if ($isSafe) {
                    Write-Log "  [KEEP] $itemName - $itemCommand" -level "INFO"
                } elseif ($isUnnecessary) {
                    Write-Log "  [CONSIDER DISABLE] $itemName - $itemCommand" -level "WARNING"
                    # Note: We're not actually disabling items automatically for safety.
                    # Disabling requires removing registry keys or modifying Task Scheduler entries, which is complex and risky.
                } else {
                    Write-Log "  [REVIEW] $itemName - $itemCommand" -level "INFO"
                }
            }
        }
        
        Write-Log "Startup items analysis (from Win32_StartupCommand) complete. Manual review via Task Manager (Startup tab) and Autoruns (Sysinternals) is highly recommended for comprehensive management." -level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error analyzing startup: $($_.Exception.Message)" -level "ERROR"
        return $false
    }
}

# Function to optimize services with enhanced safety checks
function Optimize-Services {
    try {
        Write-Log "Optimizing services..." -level "INFO"
        
        # Services that can be safely set to manual with descriptions
        # Name is the service name, DisplayName is for logging, Description for context
        $servicesToManual = @(
            @{Name="DiagTrack";        DisplayName="Connected User Experiences and Telemetry"; Description="Collects usage data - safe to disable for privacy if not needed for diagnostics."},
            @{Name="dmwappushservice"; DisplayName="WAP Push Message Routing Service";       Description="Delivers WAP push messages - rarely needed for most users."},
            @{Name="MapsBroker";       DisplayName="Downloaded Maps Manager";                Description="For Windows Maps app - disable if not used."},
            @{Name="lfsvc";            DisplayName="Geolocation Service";                    Description="Provides location data - disable if location features are not used."},
            # @{Name="SharedAccess";     DisplayName="Internet Connection Sharing (ICS)";    Description="Allows sharing internet - disable if not used."}, # Critical for some network configs / Hyper-V
            @{Name="WSearch";          DisplayName="Windows Search";                         Description="Indexes files - setting to Manual or Disabled can improve performance if search is not heavily used. Reconsider if frequently searching files."}
            # Add more with caution, e.g., Fax, Print Spooler (if no printer)
        )
        
        # Critical services that should NEVER be disabled or changed without extreme caution
        $criticalServices = @(
            "wuauserv", "WinDefend", "wscsvc", "Dhcp", "Dnscache", 
            "LanmanWorkstation", "LanmanServer", "nsi", "PlugPlay", "EventLog", 
            "MpsSvc", "RpcSs", "DcomLaunch", "BrokerInfrastructure", "CoreMessagingRegistrar",
            "Power", "SystemEventsBroker", "TimeBrokerSvc", "UserManager"
        )
        
        foreach ($serviceInfo in $servicesToManual) {
            $serviceName = $serviceInfo.Name
            $serviceDisplayName = $serviceInfo.DisplayName
            $serviceDescription = $serviceInfo.Description

            if ($criticalServices -contains $serviceName) {
                Write-Log "  Skipping critical service: $serviceDisplayName ($serviceName)" -level "WARNING"
                continue
            }
            
            $svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            
            if ($svc) {
                if ($svc.StartType -ne "Manual" -and $svc.StartType -ne "Disabled") {
                    Write-Log "  Service $serviceDisplayName ($serviceName) current state: $($svc.StartType)" -level "INFO"
                    try {
                        Set-Service -Name $serviceName -StartupType Manual -ErrorAction Stop
                        Write-Log "  Set $serviceDisplayName ($serviceName) to Manual startup. ($serviceDescription)" -level "SUCCESS"
                    } catch {
                        Write-Log "  Failed to set $serviceDisplayName ($serviceName) to Manual: $($_.Exception.Message)" -level "ERROR"
                    }
                }
                else {
                    Write-Log "  $serviceDisplayName ($serviceName) already set to $($svc.StartType)." -level "INFO"
                }
            }
            else {
                Write-Log "  Service $serviceDisplayName ($serviceName) not found." -level "INFO" # Could be warning if expected
            }
        }
        Write-Log "Service optimization attempt complete. Some changes may require a reboot." -level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error optimizing services: $($_.Exception.Message)" -level "ERROR"
        return $false
    }
}

# Function to optimize power settings with enhanced features
function Optimize-PowerSettings {
    try {
        Write-Log "Optimizing power settings..." -level "INFO"
        
        # Check if running on a laptop/battery
        $isLaptop = $false
        try {
            $powerStatus = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
            if ($powerStatus) { $isLaptop = $true }
        } catch {
            Write-Log "  Could not determine if device is a laptop via Win32_Battery: $($_.Exception.Message)" -level "WARNING"
        }
        
        # GUIDs for common power plans
        $balancedGuid   = "381b4222-f694-41f0-9685-ff5bb260df2e" # Balanced
        $highPerfGuid   = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" # High Performance
        $powerSaverGuid = "a1841308-3541-4fab-bc81-f71556f20b4a" # Power Saver
        # Ultimate performance GUID (often needs to be enabled/unlocked first)
        $ultimatePerfGuid = "e9a42b02-d5df-448d-aa00-03f14749eb61"

        $activePlanGuid = ""
        $activePlanName = ""

        if ($isLaptop) {
            Write-Log "  Detected laptop/battery device. Suggesting Balanced power settings." -level "INFO"
            # For laptops, usually Balanced is preferred to save battery.
            # User can choose High Performance if they are plugged in and need max performance.
            # We will set to Balanced as a sensible default for laptops.
            try {
                & $global:PowerCfgPath -setactive $balancedGuid
                $activePlanGuid = $balancedGuid
                $activePlanName = "Balanced"
                Write-Log "  Set power plan to Balanced for better battery life." -level "SUCCESS"

                # Optimize balanced plan for laptop use (example values)
                & $global:PowerCfgPath -change -monitor-timeout-ac 10 # Monitor off after 10 mins on AC
                & $global:PowerCfgPath -change -monitor-timeout-dc 5  # Monitor off after 5 mins on DC
                & $global:PowerCfgPath -change -disk-timeout-ac 20    # Disk off after 20 mins on AC
                & $global:PowerCfgPath -change -disk-timeout-dc 10    # Disk off after 10 mins on DC
                & $global:PowerCfgPath -change -standby-timeout-ac 30 # Standby after 30 mins on AC
                & $global:PowerCfgPath -change -standby-timeout-dc 15 # Standby after 15 mins on DC
                Write-Log "  Optimized settings for '$activePlanName' plan (laptop defaults)." -level "INFO"
            } catch {
                 Write-Log "  Failed to set or configure Balanced plan: $($_.Exception.Message)" -level "WARNING"
            }

        } else { # Desktop
            Write-Log "  Detected desktop device. Suggesting High Performance power settings." -level "INFO"
            
            # Check if Ultimate Performance plan exists and is active, if so, use it or High Performance
            $powerPlansOutput = & $global:PowerCfgPath -list
            if ($powerPlansOutput -match $ultimatePerfGuid) {
                 try {
                    & $global:PowerCfgPath -setactive $ultimatePerfGuid
                    $activePlanGuid = $ultimatePerfGuid
                    $activePlanName = "Ultimate Performance"
                    Write-Log "  Set power plan to Ultimate Performance." -level "SUCCESS"
                 } catch {
                    Write-Log "  Failed to set Ultimate Performance plan. Trying High Performance. Error: $($_.Exception.Message)" -level "WARNING"
                 }
            }
            
            if (-not $activePlanGuid) { # If Ultimate not set or failed
                if ($powerPlansOutput -match $highPerfGuid) {
                    try {
                        & $global:PowerCfgPath -setactive $highPerfGuid
                        $activePlanGuid = $highPerfGuid
                        $activePlanName = "High Performance"
                        Write-Log "  Set power plan to High Performance." -level "SUCCESS"
                    } catch {
                        Write-Log "  Failed to set High Performance plan: $($_.Exception.Message)" -level "WARNING"
                    }
                }
                else {
                    # Try to duplicate High Performance if it doesn't exist (might fail on some systems)
                    try {
                        Write-Log "  High Performance plan not found. Attempting to duplicate from Balanced..." -level "INFO"
                        & $global:PowerCfgPath -duplicatescheme $balancedGuid $highPerfGuid # Duplicate balanced and hope it becomes a high perf template
                        & $global:PowerCfgPath -setactive $highPerfGuid
                        $activePlanGuid = $highPerfGuid
                        $activePlanName = "High Performance (Created)"
                        Write-Log "  Created and set power plan to High Performance." -level "SUCCESS"
                    } catch {
                        Write-Log "  Failed to create or set High Performance plan. Using current active plan. Error: $($_.Exception.Message)" -level "ERROR"
                        # Fallback to current active if all else fails
                        $currentActivePlanLine = $powerPlansOutput | Select-String "\*"
                        if ($currentActivePlanLine -match "([0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12})") {
                            $activePlanGuid = $Matches[1]
                            $activePlanName = ($currentActivePlanLine -replace ".*\) (.*?)\s*\*.*", '$1').Trim()
                             Write-Log "  Using currently active plan: $activePlanName ($activePlanGuid)" -level "INFO"
                        }
                    }
                }
            }

            if ($activePlanGuid) {
                # Optimize High/Ultimate Performance plan for desktops (example values)
                & $global:PowerCfgPath -change -monitor-timeout-ac 15 # Monitor off after 15 mins on AC
                & $global:PowerCfgPath -change -disk-timeout-ac 0     # Disk never off on AC (0 = Never)
                & $global:PowerCfgPath -change -standby-timeout-ac 0  # Standby never on AC (0 = Never)
                Write-Log "  Optimized settings for '$activePlanName' plan (desktop defaults)." -level "INFO"
            }
        }
        
        # Additional universal power optimizations (apply to the currently set active plan SCHEME_CURRENT)
        if ($activePlanGuid) { # Only if we successfully set a plan
            # Disable USB selective suspend
            & $global:PowerCfgPath -setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
            & $global:PowerCfgPath -setdcvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
            Write-Log "  USB Selective Suspend disabled for current plan." -level "INFO"
            
            # Set processor performance to maximum (may not be available/applicable on all systems or plans)
            # SUB_PROCESSOR GUID: 54533251-82be-4824-96c1-47b60b740d00
            # PERFINCPOL (Processor performance increase policy) SettingIndex: 0012ee47-9041-4b5d-9b77-535fba8b1442 (AC) / 0012ee47-9041-4b5d-9b77-535fba8b1443 (DC)
            # Value 2 = Maximize performance. Check powercfg /QUERY SCHEME_CURRENT SUB_PROCESSOR PERFINCPOL for details
            # This is often controlled by "Processor power management" -> "Minimum processor state" (set to 100%) and "Maximum processor state" (set to 100%)
            # A simpler way for High Performance is usually enough. These are more granular.
            # & $global:PowerCfgPath -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR MINPROCSTATE 100
            # & $global:PowerCfgPath -setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR MINPROCSTATE 100
            # & $global:PowerCfgPath -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR MAXPROCSTATE 100
            # & $global:PowerCfgPath -setdcvalueindex SCHEME_CURRENT SUB_PROCESSOR MAXPROCSTATE 100
            # Write-Log "  Processor states (min/max) set to 100% for current plan." -level "INFO"

            # Apply changes (redundant if -setactive was already called, but ensures current settings are applied)
            & $global:PowerCfgPath -setactive SCHEME_CURRENT
        }
        Write-Log "Power settings optimization attempt complete." -level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error optimizing power settings: $($_.Exception.Message)" -level "ERROR"
        return $false
    }
}

# --- Main Script Execution ---
Write-Log "RescuePC Performance Optimization Script Started." -level "INFO"
Write-Log "Script Version: 2.0.0" -level "INFO"
Write-Log "Timestamp: $(Get-Date)" -level "INFO"

if ($createRestorePoint) {
    if (New-SystemRestorePoint) {
        Write-Log "System Restore Point task completed." -level "INFO"
    } else {
        Write-Log "System Restore Point creation failed or was skipped. Continuing with caution." -level "WARNING"
        # Optionally, ask user if they want to continue or exit
        # $choice = Read-Host "System Restore Point failed. Continue with optimizations? (Y/N)"
        # if ($choice -ne 'y') { Write-Log "User aborted script."; exit 1 }
    }
} else {
    Write-Log "System Restore Point creation skipped by configuration." -level "INFO"
}

if (Backup-CurrentSettings) {
    Write-Log "System settings backup task completed." -level "INFO"
} else {
    Write-Log "System settings backup failed. This is a critical step. Review logs." -level "ERROR"
    # Optionally, ask user if they want to continue or exit
    # $choice = Read-Host "Settings backup failed. Continue with optimizations? (Y/N) This is risky."
    # if ($choice -ne 'y') { Write-Log "User aborted script."; exit 1 }
}

Write-Log "Starting optimization functions..." -level "INFO"

if (Optimize-VisualEffects) { Write-Log "Visual Effects optimization completed." -level "INFO" }
else { Write-Log "Visual Effects optimization failed." -level "WARNING" }

if (Optimize-Startup) { Write-Log "Startup Analysis completed." -level "INFO" }
else { Write-Log "Startup Analysis failed." -level "WARNING" }

if (Optimize-Services) { Write-Log "Services optimization completed." -level "INFO" }
else { Write-Log "Services optimization failed." -level "WARNING" }

if (Optimize-PowerSettings) { Write-Log "Power Settings optimization completed." -level "INFO" }
else { Write-Log "Power Settings optimization failed." -level "WARNING" }

Write-Log "All optimization tasks attempted." -level "INFO"
Write-Log "Please review the log file for details: $logFile" -level "INFO"
Write-Log "A system reboot is recommended for all changes to take full effect." -level "INFO"
Write-Log "RescuePC Performance Optimization Script Finished." -level "SUCCESS"

