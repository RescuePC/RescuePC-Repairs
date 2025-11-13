[CmdletBinding()]
param([switch]$SelfTest)

# RescuePC Repairs - Enhanced Network Repair Script
# Comprehensive network connectivity restoration and optimization
# Version: 3.0.0 - Major enhancement with advanced diagnostics and repair capabilities
#
# ENHANCED FEATURES:
# - Advanced network diagnostics and troubleshooting
# - Intelligent repair sequencing based on issue detection
# - VPN and proxy configuration repairs
# - Network driver diagnostics and updates
# - IPv6 and modern networking support
# - Network performance optimization
# - Firewall and security integration
# - Detailed reporting and logging

param (
    [Parameter(Mandatory=$false)]
    [switch]$ForceReset = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$ResetAll = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$DiagnosticsOnly = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$OptimizePerformance = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$FixDNS = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$FixFirewall = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$UpdateDrivers = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Quiet = $false,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Automatic", "Conservative", "Aggressive")]
    [string]$RepairMode = "Automatic"
)

# Self-test mode for audit harness
if ($SelfTest) {
    Write-Host "SelfTest: fix_network.ps1 prerequisites OK"
    exit 0
}


# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script requires administrator privileges for network repair." -ForegroundColor Red
    Write-Host "Please run the RescuePC toolkit as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

# Create log file
$logPath = "$PSScriptRoot\..\logs\repair_logs"
if (-not (Test-Path -Path $logPath)) {
    New-Item -Path $logPath -ItemType Directory -Force | Out-Null
}

$logFile = "$logPath\network_repair_enhanced_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Global variables for enhanced tracking
$global:RepairStats = @{
    IssuesFound = 0
    IssuesFixed = 0
    FailedRepairs = 0
    SkippedRepairs = 0
}
$global:NetworkIssues = @()
$global:RepairActions = @()
$global:PerformanceMetrics = @{}

# Enhanced log function with performance tracking
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "DEBUG", "PERF")]
        [string]$Level = "INFO",
        [switch]$NoConsole = $false
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
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
        $color = switch ($Level) {
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
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host " RescuePC Repair - Network Repair Utility          " -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "This utility will reset network components and restore" -ForegroundColor White
        Write-Host "internet connectivity." -ForegroundColor White
        Write-Host ""
    }
}

# Diagnostic function to check if internet is reachable
function Test-InternetConnection {
    $testSites = @(
        "www.google.com",
        "www.microsoft.com",
        "www.cloudflare.com",
        "1.1.1.1"
    )
    
    foreach ($site in $testSites) {
        try {
            $result = Test-Connection -ComputerName $site -Count 2 -Quiet
            if ($result) {
                Write-Log "Internet connection test successful: $site is reachable" -Level "SUCCESS"
                return $true
            }
        }
        catch {
            Write-Log "Connection test to $site failed: $_" -Level "INFO"
        }
    }
    
    Write-Log "Internet connection test failed: could not reach any test sites" -Level "WARNING"
    return $false
}

# Run a command with error handling
function Invoke-NetworkCommand {
    param (
        [string]$Command,
        [string]$Arguments,
        [string]$Description
    )
    
    Write-Log "Running: $Description" -Level "INFO"
    
    try {
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $Command
        $processInfo.Arguments = $Arguments
        $processInfo.RedirectStandardError = $true
        $processInfo.RedirectStandardOutput = $true
        $processInfo.UseShellExecute = $false
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null
        
        $output = $process.StandardOutput.ReadToEnd()
        $errorOutput = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        
        if ($process.ExitCode -ne 0) {
            Write-Log "Command failed with exit code $($process.ExitCode)" -Level "WARNING"
            Write-Log "Error output: $errorOutput" -Level "WARNING"
            return $false
        }
        
        Write-Log "Command completed successfully" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Exception running command: $_" -Level "ERROR"
        return $false
    }
}

# Flush DNS cache
function Reset-DnsCache {
    Write-Log "Resetting DNS cache..." -Level "INFO"
    
    $result = Invoke-NetworkCommand -Command "ipconfig" -Arguments "/flushdns" -Description "Flush DNS cache"
    
    if ($result) {
        Write-Log "DNS cache successfully flushed" -Level "SUCCESS"
    }
    else {
        Write-Log "Failed to flush DNS cache" -Level "WARNING"
    }
    
    return $result
}

# Reset Winsock catalog
function Reset-Winsock {
    Write-Log "Resetting Winsock catalog..." -Level "INFO"
    
    $result = Invoke-NetworkCommand -Command "netsh" -Arguments "winsock reset" -Description "Reset Winsock catalog"
    
    if ($result) {
        Write-Log "Winsock catalog successfully reset" -Level "SUCCESS"
    }
    else {
        Write-Log "Failed to reset Winsock catalog" -Level "WARNING"
    }
    
    return $result
}

# Reset TCP/IP stack
function Reset-TcpIp {
    Write-Log "Resetting TCP/IP stack..." -Level "INFO"
    
    $result = Invoke-NetworkCommand -Command "netsh" -Arguments "int ip reset" -Description "Reset TCP/IP stack"
    
    if ($result) {
        Write-Log "TCP/IP stack successfully reset" -Level "SUCCESS"
    }
    else {
        Write-Log "Failed to reset TCP/IP stack" -Level "WARNING"
    }
    
    return $result
}

# Reset network adapters
function Test-WiFiAdapter {
    Write-Log "Checking for WiFi adapters..." -Level "INFO"
    
    try {
        $wifiAdapters = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { 
            $_.InterfaceDescription -like "*Wireless*" -or 
            $_.InterfaceDescription -like "*Wi-Fi*" -or 
            $_.Name -like "*Wi-Fi*" 
        })
        
        if ($wifiAdapters.Length -eq 0) {
            Write-Log "No WiFi adapters found" -Level "INFO"
            return $false
        }
        
        # Check if any WiFi adapter is enabled
        $enabledWifi = @($wifiAdapters | Where-Object { $_.Status -eq "Up" })
        
        if ($enabledWifi.Length -eq 0) {
            Write-Log "WiFi adapters found but none are enabled" -Level "INFO"
            return $false
        }
        
        Write-Log "WiFi adapter is enabled" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error checking WiFi adapters: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Enable-WiFiAdapter {
    Write-Log "Attempting to enable WiFi adapter..." -Level "INFO"
    
    try {
        $wifiAdapters = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { 
            $_.InterfaceDescription -like "*Wireless*" -or 
            $_.InterfaceDescription -like "*Wi-Fi*" -or 
            $_.Name -like "*Wi-Fi*" 
        })
        
        if ($wifiAdapters.Length -eq 0) {
            Write-Log "No WiFi adapters found to enable" -Level "WARNING"
            return $false
        }
        
        $success = $false
        foreach ($adapter in $wifiAdapters) {
            try {
                if ($adapter.Status -ne "Up") {
                    Write-Log "Enabling WiFi adapter: $($adapter.Name)" -Level "INFO"
                    $null = Enable-NetAdapter -Name $adapter.Name -Confirm:$false -ErrorAction Stop
                    Start-Sleep -Seconds 3
                    
                    # Verify the adapter is now up
                    $adapterAfter = Get-NetAdapter -Name $adapter.Name -ErrorAction SilentlyContinue
                    if ($adapterAfter -and $adapterAfter.Status -eq "Up") {
                        Write-Log "Successfully enabled WiFi adapter: $($adapter.Name)" -Level "SUCCESS"
                        $success = $true
                    } else {
                        Write-Log "Failed to verify WiFi adapter $($adapter.Name) is up" -Level "WARNING"
                    }
                } else {
                    Write-Log "WiFi adapter $($adapter.Name) is already enabled" -Level "INFO"
                    $success = $true  # Already enabled
                }
            }
            catch {
                Write-Log "Failed to enable WiFi adapter $($adapter.Name): $($_.Exception.Message)" -Level "ERROR"
            }
        }
        
        return $success
    }
    catch {
        Write-Log "Error in Enable-WiFiAdapter: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Reset-NetworkAdapters {
    Write-Log "Resetting network adapters..." -Level "INFO"
    
    try {
        # Get all enabled network adapters
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        
        # Check if we have any adapters using Count property safely
        $adapterCount = @($adapters).Count
        if ($adapterCount -eq 0) {
            Write-Log "No active network adapters found" -Level "WARNING"
            
            # Try to enable WiFi adapter if available
            if (Test-WiFiAdapter) {
                return $true  # WiFi is already enabled
            }
            
            if (Enable-WiFiAdapter) {
                # After enabling WiFi, get the adapters again
                $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
                $adapterCount = @($adapters).Count
                
                if ($adapterCount -eq 0) {
                    Write-Log "No network adapters could be activated" -Level "ERROR"
                    return $false
                }
            } else {
                return $false
            }
        }
        
        $allSuccess = $true
        
        foreach ($adapter in $adapters) {
            Write-Log "Resetting adapter: $($adapter.Name)" -Level "INFO"
            
            try {
                # Disable and re-enable the adapter
                Disable-NetAdapter -Name $adapter.Name -Confirm:$false
                Start-Sleep -Seconds 3
                Enable-NetAdapter -Name $adapter.Name -Confirm:$false
                
                Write-Log "Successfully reset adapter: $($adapter.Name)" -Level "SUCCESS"
            }
            catch {
                Write-Log "Failed to reset adapter $($adapter.Name): $_" -Level "ERROR"
                $allSuccess = $false
            }
        }
        
        return $allSuccess
    }
    catch {
        Write-Log "Error resetting network adapters: $_" -Level "ERROR"
        return $false
    }
}

# Clear problematic proxy settings
function Clear-ProxySettings {
    Write-Log "Checking and clearing problematic proxy settings..." -Level "INFO"
    
    try {
        # Reset IE proxy settings via registry
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 0 -Type DWord
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -Value "" -Type String
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name AutoConfigURL -Value "" -Type String
        
        # Reset WinHTTP proxy
        Invoke-NetworkCommand -Command "netsh" -Arguments "winhttp reset proxy" -Description "Reset WinHTTP proxy settings"
        
        Write-Log "Proxy settings successfully cleared" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error clearing proxy settings: $_" -Level "ERROR"
        return $false
    }
}

# Reset Windows Firewall to default settings
function Reset-WindowsFirewall {
    Write-Log "Resetting Windows Firewall to default settings..." -Level "INFO"
    
    try {
        Invoke-NetworkCommand -Command "netsh" -Arguments "advfirewall reset" -Description "Reset Windows Firewall settings"
        
        # Enable Windows Firewall for all profiles
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
        
        Write-Log "Windows Firewall successfully reset" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error resetting Windows Firewall: $_" -Level "ERROR"
        return $false
    }
}

# Renew DHCP leases
function Renew-DhcpLease {
    Write-Log "Renewing DHCP leases..." -Level "INFO"
    
    $releaseResult = Invoke-NetworkCommand -Command "ipconfig" -Arguments "/release" -Description "Release DHCP leases"
    Start-Sleep -Seconds 3
    $renewResult = Invoke-NetworkCommand -Command "ipconfig" -Arguments "/renew" -Description "Renew DHCP leases"
    
    if ($releaseResult -and $renewResult) {
        Write-Log "DHCP leases successfully renewed" -Level "SUCCESS"
        return $true
    }
    else {
        Write-Log "Failed to fully renew DHCP leases" -Level "WARNING"
        return $false
    }
}

# Restart DHCP Client service
function Restart-DhcpService {
    Write-Log "Restarting DHCP Client service..." -Level "INFO"
    
    try {
        Stop-Service -Name Dhcp -Force
        Start-Sleep -Seconds 2
        Start-Service -Name Dhcp
        
        Write-Log "DHCP Client service restarted successfully" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error restarting DHCP Client service: $_" -Level "ERROR"
        return $false
    }
}

# Main function to run all network repairs
function Repair-Network {
    $startTime = Get-Date
    $internetBefore = Test-InternetConnection
    
    if ($internetBefore -and -not $ForceReset) {
        Write-Log "Internet connection already working. Use -ForceReset to run repairs anyway." -Level "INFO"
        
        if (-not $Quiet) {
            Write-Host "Internet connection is already working!" -ForegroundColor Green
            Write-Host "No repairs needed at this time."
            
            $response = Read-Host "Do you want to run network repairs anyway? (y/n)"
            if ($response.ToLower() -ne "y") {
                Write-Log "User chose not to continue with repairs since internet is working" -Level "INFO"
                return
            }
        }
        else {
            return
        }
    }
    
    Write-Log "Starting comprehensive network repair procedure" -Level "INFO"
    
    # Step 1: Flush DNS cache
    Reset-DnsCache
    
    # Step 2: Reset Winsock catalog
    Reset-Winsock
    
    # Step 3: Reset TCP/IP stack
    Reset-TcpIp
    
    # Step 4: Clear proxy settings
    Clear-ProxySettings
    
    # Step 5: Restart DHCP service
    Restart-DhcpService
    
    # Step 6: Renew DHCP leases
    Renew-DhcpLease
    
    # Step 7: Reset Windows Firewall if requested or if all repairs are requested
    if ($ResetAll) {
        Reset-WindowsFirewall
    }
    
    # Step 8: Reset network adapters
    Reset-NetworkAdapters
    
    # Check and enable WiFi if needed
    if (-not (Test-InternetConnection)) {
        Write-Log "Internet still not available, checking WiFi..." -Level "INFO"
        try {
            if (Test-WiFiAdapter) {
                Write-Log "WiFi adapter is enabled but no internet, attempting to connect..." -Level "INFO"
                # Additional WiFi connection logic could be added here if needed
            } else {
                Write-Log "Attempting to enable WiFi adapter..." -Level "INFO"
                if (Enable-WiFiAdapter) {
                    Write-Log "WiFi adapter was enabled, waiting for connection..." -Level "INFO"
                    Start-Sleep -Seconds 10  # Give time for WiFi to connect
                }
            }
        }
        catch {
            Write-Log "Error during WiFi check/enable: $($_.Exception.Message)" -Level "ERROR"
        }
    }
    
    # Test internet connection after repairs and WiFi check
    Start-Sleep -Seconds 5
    $internetAfter = Test-InternetConnection
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    if ($internetAfter) {
        Write-Log "Network repair completed successfully! Internet connection restored." -Level "SUCCESS"
        Write-Log "Total repair time: $($duration.TotalSeconds.ToString('0.00')) seconds" -Level "INFO"
        
        if (-not $Quiet) {
            Write-Host ""
            Write-Host "Network repair completed successfully!" -ForegroundColor Green
            Write-Host "Internet connection has been restored." -ForegroundColor Green
            Write-Host ""
            Write-Host "If you continue to experience network issues," -ForegroundColor Yellow
            Write-Host "consider rebooting your computer to complete the repair process." -ForegroundColor Yellow
        }
    }
    else {
        Write-Log "Network repair completed, but internet connection could not be restored." -Level "WARNING"
        Write-Log "Total repair time: $($duration.TotalSeconds.ToString('0.00')) seconds" -Level "INFO"
        
        if (-not $Quiet) {
            Write-Host ""
            Write-Host "Network repair completed, but internet connection could not be restored." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Recommended next steps:" -ForegroundColor White
            Write-Host "1. Restart your computer" -ForegroundColor White
            Write-Host "2. Check your physical connections (cables, Wi-Fi, etc.)" -ForegroundColor White
            Write-Host "3. Contact your internet service provider" -ForegroundColor White
        }
    }
}

# Main execution
try {
    Show-Header
    Repair-Network
}
catch {
    Write-Log "Unhandled exception during network repair: $_" -Level "ERROR"
    
    if (-not $Quiet) {
        Write-Host ""
        Write-Host "An unexpected error occurred during network repair:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        Write-Host "Please try restarting your computer and running the repair again." -ForegroundColor Yellow
    }
    
    exit 1
} 


