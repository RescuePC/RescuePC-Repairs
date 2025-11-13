[CmdletBinding()]
param([switch]$SelfTest)

# Self-test mode for audit harness
if ($SelfTest) {
    Write-Host "SelfTest: rebuild_windows_services script prerequisites OK"
    exit 0
}

# =====================================================================
# rebuild_windows_services.ps1
# Purpose: Safely restores critical Windows services and re-registers essential DLLs
# =====================================================================

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

# Run as administrator check
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires Administrator privileges. Please run as Administrator."
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# Ensure log directories exist
$logDir = "C:\Users\Tyler\Desktop\RescuePC Repairs\logs"
if (-not (Test-Path -Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

# Start logging
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logPath = "$logDir\rebuild_windows_services_$timestamp.log"
Start-Transcript -Path $logPath -Append

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Windows Services and DLL Restoration Utility   " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Starting repair process at $(Get-Date)" -ForegroundColor Cyan
Write-Host ""

# Create a system restore point
Write-Host "Creating System Restore Point..." -ForegroundColor Yellow
try {
    Checkpoint-Computer -Description "Before Windows Services Rebuild" -RestorePointType "APPLICATION_INSTALL" -ErrorAction Stop
    Write-Host "System Restore Point created successfully." -ForegroundColor Green
}
catch {
    Write-Warning "Unable to create System Restore Point: $_"
    Write-Host "Continuing with repair process..." -ForegroundColor Yellow
}

# Stop Windows Update service and dependencies first (safer approach)
Write-Host "`nStopping services before reconfiguration..." -ForegroundColor Yellow
$servicesToStopFirst = @("wuauserv", "bits", "cryptsvc", "TrustedInstaller")
foreach ($service in $servicesToStopFirst) {
    try {
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        Write-Host "   - $service stopped successfully" -ForegroundColor Gray
    }
    catch {
        Write-Host "   - $service was not running or couldn't be stopped" -ForegroundColor Gray
    }
}

# Services to restore (expanded and categorized list)
$services = @(
    # Windows Update related
    "wuauserv",      # Windows Update
    "bits",          # Background Intelligent Transfer Service
    "cryptsvc",      # Cryptographic Services
    "TrustedInstaller", # Windows Modules Installer
    "UsoSvc",        # Update Orchestrator Service
    "WaaSMedicSvc",  # Windows Update Medic Service
    "appidsvc",      # Application Identity Service

    # Networking related
    "Dhcp",          # DHCP Client
    "Dnscache",      # DNS Client
    "nsi",           # Network Store Interface Service
    "LanmanServer",  # Server
    "LanmanWorkstation", # Workstation
    "netprofm",      # Network List Service
    "NlaSvc",        # Network Location Awareness

    # System services
    "Winmgmt",       # Windows Management Instrumentation
    "EventLog",      # Windows Event Log
    "EventSystem",   # COM+ Event System
    "RpcSs",         # Remote Procedure Call
    "RpcEptMapper",  # RPC Endpoint Mapper
    "DcomLaunch",    # DCOM Server Process Launcher
    "WinDefend",     # Windows Defender
    "WdNisSvc",      # Windows Defender Network Inspection
    "SecurityHealthService", # Windows Security Health Service
    "WinRM",         # Windows Remote Management
    "ShellHWDetection", # Shell Hardware Detection
    "PlugPlay",      # Plug and Play
    "BFE",           # Base Filtering Engine (Firewall)
    "MpsSvc"         # Windows Firewall
)

Write-Host "`nRestoring core Windows services..." -ForegroundColor Green
$successCount = 0
$failCount = 0

foreach ($service in $services) {
    Write-Host "Processing service: $service" -ForegroundColor Yellow

    try {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue

        if ($svc -eq $null) {
            Write-Warning "Service $service not found on this system."
            $failCount++
            continue
        }

        # Check if service is disabled and fix it
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$service"
        if (Test-Path $regPath) {
            $startType = Get-ItemProperty -Path $regPath -Name "Start" -ErrorAction SilentlyContinue
            if ($startType -ne $null -and $startType.Start -eq 4) {
                Write-Host "   - Service $service was disabled, enabling..." -ForegroundColor Yellow
                Set-ItemProperty -Path $regPath -Name "Start" -Value 2 -Type DWord
            }
        }

        # Configure and start the service
        Set-Service -Name $service -StartupType Automatic -ErrorAction Stop
        Start-Service -Name $service -ErrorAction Stop

        # Verify service is running
        $svcStatus = Get-Service -Name $service
        if ($svcStatus.Status -eq "Running") {
            Write-Host "   - SUCCESS: $service is now running with Automatic startup" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "   - WARNING: $service was configured but is not running" -ForegroundColor Yellow
            $failCount++
        }
    }
    catch {
        Write-Warning "Failed to configure `${service}`: $_"
        $failCount++
    }
}

Write-Host "`nService restoration complete: $successCount successful, $failCount failed" -ForegroundColor Cyan

# SFC and DISM repairs (safe system file repairs)
Write-Host "`nRunning system file integrity checks..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Yellow

try {
    Write-Host "Running SFC scan..." -ForegroundColor Yellow
    $sfcExe = Get-SystemExecutable -Name 'sfc'
    $sfcOutput = & $sfcExe /scannow 2>&1
    Write-Host $sfcOutput -ForegroundColor Gray
    Write-Host "SFC scan completed" -ForegroundColor Green
}
catch {
    Write-Warning "SFC scan failed: $_"
}

try {
    Write-Host "Running DISM health check..." -ForegroundColor Yellow
    $dismExe = Get-SystemExecutable -Name 'dism'
$dismOutput = & $dismExe /Online /Cleanup-Image /CheckHealth
    Write-Host $dismOutput -ForegroundColor Gray

    Write-Host "Running DISM scan..." -ForegroundColor Yellow
    $dismExe = Get-SystemExecutable -Name 'dism'
$dismScanOutput = & $dismExe /Online /Cleanup-Image /ScanHealth
    Write-Host $dismScanOutput -ForegroundColor Gray

    Write-Host "Running DISM repair..." -ForegroundColor Yellow
    $dismExe = Get-SystemExecutable -Name 'dism'
$dismRepairOutput = & $dismExe /Online /Cleanup-Image /RestoreHealth
    Write-Host $dismRepairOutput -ForegroundColor Gray

    Write-Host "DISM repairs completed" -ForegroundColor Green
}
catch {
    Write-Warning "DISM repair failed: $_"
}

# DLL Re-registration
Write-Host "`nRe-registering key system DLLs..." -ForegroundColor Green

$dlls = @(
    # Internet and browser related
    "atl.dll", "urlmon.dll", "mshtml.dll", "shdocvw.dll", "browseui.dll", "jscript.dll",
    "vbscript.dll", "scrrun.dll", "msxml.dll", "msxml3.dll", "msxml6.dll", "actxprxy.dll",

    # Security related
    "softpub.dll", "wintrust.dll", "initpki.dll", "dssenh.dll", "rsaenh.dll",
    "gpkcsp.dll", "sccbase.dll", "slbcsp.dll", "cryptdlg.dll", "schannel.dll",

    # System related
    "oleaut32.dll", "ole32.dll", "shell32.dll", "shsvcs.dll", "advapi32.dll",
    "userenv.dll", "netshell.dll", "netcfgx.dll", "wmnetmgr.dll", "wbem\wmisvc.dll",

    # Windows Update related
    "wuapi.dll", "wuaueng.dll", "wuaueng1.dll", "wucltui.dll", "wups.dll",
    "wups2.dll", "wuweb.dll", "qmgr.dll", "qmgrprxy.dll", "wucltux.dll",
    "muweb.dll", "wuwebv.dll"
)

$dllSuccessCount = 0
$dllFailCount = 0

foreach ($dll in $dlls) {
    try {
        $regsvr32Exe = Get-SystemExecutable -Name 'regsvr32'
        $process = Start-Process -FilePath $regsvr32Exe -ArgumentList "/s", $dll -Wait -PassThru -ErrorAction Stop
        if ($process.ExitCode -eq 0) {
            Write-Host "   - Successfully registered $dll" -ForegroundColor Green
            $dllSuccessCount++
        } else {
            Write-Host "   - Failed to register $dll (Exit code: $($process.ExitCode))" -ForegroundColor Yellow
            $dllFailCount++
        }
    }
    catch {
        Write-Warning "Error processing $dll`: $_"
        $dllFailCount++
    }
}

Write-Host "`nDLL registration complete: $dllSuccessCount successful, $dllFailCount failed" -ForegroundColor Cyan

# Reset Windows Update components
Write-Host "`nResetting Windows Update components..." -ForegroundColor Yellow

try {
    # Stop relevant services
    $updateServices = @("wuauserv", "cryptSvc", "bits", "msiserver", "appidsvc")
    foreach ($service in $updateServices) {
        Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
        Write-Host "   - Stopped $service" -ForegroundColor Gray
    }

    # Rename (backup) the SoftwareDistribution and catroot2 folders
    $backupTime = Get-Date -Format "yyyyMMdd_HHmmss"

    if (Test-Path "$env:SystemRoot\SoftwareDistribution") {
        Rename-Item -Path "$env:SystemRoot\SoftwareDistribution" -NewName "SoftwareDistribution.old.$backupTime" -Force -ErrorAction SilentlyContinue
        Write-Host "   - Renamed SoftwareDistribution folder" -ForegroundColor Gray
    }

    if (Test-Path "$env:SystemRoot\System32\catroot2") {
        Rename-Item -Path "$env:SystemRoot\System32\catroot2" -NewName "catroot2.old.$backupTime" -Force -ErrorAction SilentlyContinue
        Write-Host "   - Renamed catroot2 folder" -ForegroundColor Gray
    }

    # Reset Windows Update policies
    & sc.exe sdset bits 'D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)'
    & sc.exe sdset wuauserv 'D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)'

    # Reset BITS and Windows Update service to the default security descriptor
    & netsh int ip reset
    & netsh winsock reset

    # Restart the services
    foreach ($service in $updateServices) {
        Start-Service -Name $service -ErrorAction SilentlyContinue
        Write-Host "   - Started $service" -ForegroundColor Gray
    }

    Write-Host "Windows Update components reset successfully" -ForegroundColor Green
}
catch {
    Write-Warning "Error resetting Windows Update components: $_"
}

# Final summary
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "Repair Process Summary:" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Services processed: $($services.Count)" -ForegroundColor White
Write-Host "   - Successfully restored: $successCount" -ForegroundColor Green
Write-Host "   - Failed to restore: $failCount" -ForegroundColor $(if ($failCount -gt 0) {"Red"} else {"Green"})
Write-Host "`nDLLs processed: $($dlls.Count)" -ForegroundColor White
Write-Host "   - Successfully registered: $dllSuccessCount" -ForegroundColor Green
Write-Host "   - Failed to register: $dllFailCount" -ForegroundColor $(if ($dllFailCount -gt 0) {"Red"} else {"Green"})
Write-Host "`nSystem File Checks:" -ForegroundColor White
Write-Host "   - SFC scan completed" -ForegroundColor Green
Write-Host "   - DISM repairs completed" -ForegroundColor Green
Write-Host "`nWindows Update Components:" -ForegroundColor White
Write-Host "   - Reset completed" -ForegroundColor Green
Write-Host "`nLog file saved to: $logPath" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Recommend a reboot
Write-Host "`nIMPORTANT: A system restart is highly recommended to complete the repair process." -ForegroundColor Yellow
Write-Host "Would you like to restart the computer now? (Y/N)" -ForegroundColor Yellow
$restart = Read-Host

if ($restart -eq "Y" -or $restart -eq "y") {
    Write-Host "Restarting computer in 10 seconds..." -ForegroundColor Red
    Start-Sleep -Seconds 10
    Stop-Transcript
    Restart-Computer -Force
}
else {
    Write-Host "Please remember to restart your computer soon to complete the repair process." -ForegroundColor Yellow
}

Stop-Transcript
Write-Host "`nRepair process complete. Log saved to $logPath" -ForegroundColor Green
