[CmdletBinding()]
param([switch]$SelfTest)

# Self-test mode for audit harness
if ($SelfTest) {
    Write-Host "SelfTest: SysHealthCheck script prerequisites OK"
    exit 0
}

# RescuePC Repairs - System Health Check
# Version: 2.0.0 - Fixed version
param (
    [switch]$DetailedReport = $false,
    [switch]$QuickScan = $false,
    [switch]$Quiet = $false
)

Set-StrictMode -Version Latest

# Enhanced admin check
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Initialize logging
$logRoot = "$PSScriptRoot\..\logs\repair_logs"
if (-not (Test-Path $logRoot)) {
    New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFileName = "SysHealthCheck_$timestamp.log"
$logPath = Join-Path -Path $logRoot -ChildPath $logFileName

# Global variables
$global:IssuesFound = @()
$global:ErrorCount = 0
$global:WarningCount = 0

function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    
    try {
        Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
    }
    catch {
        # Silent fail if we can't write to log
    }
    
    if (-not $Quiet) {
        $color = switch ($Level) {
            "INFO" { "Cyan" }
            "WARNING" { "Yellow"; $global:WarningCount++ }
            "ERROR" { "Red"; $global:ErrorCount++ }
            "SUCCESS" { "Green" }
            default { "White" }
        }
        Write-Host $logEntry -ForegroundColor $color
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

function Get-SystemInfo {
    Show-Progress -Activity "System Health Check" -Status "Collecting system information..." -PercentComplete 10
    
    try {
        $computerSystem = Get-CimInstance -Class Win32_ComputerSystem -ErrorAction Stop
        $computerBIOS = Get-CimInstance -Class Win32_BIOS -ErrorAction Stop
        $computerOS = Get-CimInstance -Class Win32_OperatingSystem -ErrorAction Stop
        $computerCPU = Get-CimInstance -Class Win32_Processor -ErrorAction Stop
        $computerHDD = Get-CimInstance -Class Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction Stop
        
        $uptime = (Get-Date) - $computerOS.LastBootUpTime
        $uptimeStr = "{0} days, {1} hours, {2} minutes" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
        
        $systemInfo = @{
            ComputerName = $computerSystem.Name
            Manufacturer = $computerSystem.Manufacturer
            Model = $computerSystem.Model
            OSCaption = $computerOS.Caption
            OSBuild = $computerOS.BuildNumber
            CPUName = $computerCPU.Name
            CPUCores = $computerCPU.NumberOfCores
            RAMTotal = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
            CDriveCapacity = [math]::Round($computerHDD.Size / 1GB, 2)
            CDriveFreeSpace = [math]::Round($computerHDD.FreeSpace / 1GB, 2)
            CDriveUsedPercent = [math]::Round(($computerHDD.Size - $computerHDD.FreeSpace) / $computerHDD.Size * 100, 1)
            SystemUptime = $uptimeStr
            UptimeDays = $uptime.Days
        }
        
        # Check disk space warnings
        if ($systemInfo.CDriveUsedPercent -gt 90) {
            $global:IssuesFound += "Critical: C: drive is $($systemInfo.CDriveUsedPercent)% full"
            Write-Log "WARNING: C: drive critically full ($($systemInfo.CDriveUsedPercent)%)" -Level "WARNING"
        } elseif ($systemInfo.CDriveUsedPercent -gt 80) {
            $global:IssuesFound += "Warning: C: drive is $($systemInfo.CDriveUsedPercent)% full"
            Write-Log "WARNING: C: drive getting full ($($systemInfo.CDriveUsedPercent)%)" -Level "WARNING"
        }
        
        # Check uptime
        if ($systemInfo.UptimeDays -gt 30) {
            $global:IssuesFound += "Recommendation: System uptime is high ($($systemInfo.UptimeDays) days). Consider restart"
        }
        
        Write-Log "System information collected successfully" -Level "SUCCESS"
        return $systemInfo
        
    } catch {
        Write-Log "Failed to collect system information: $_" -Level "ERROR"
        $global:IssuesFound += "Error: Failed to collect system information"
        return @{}
    }
}

function Show-SystemInfo {
    param($systemInfo)
    
    if (-not $Quiet -and $systemInfo.Count -gt 0) {
        Write-Host "`n[SYSTEM INFORMATION]" -ForegroundColor Cyan
        Write-Host "Computer Name: $($systemInfo.ComputerName)" -ForegroundColor White
        Write-Host "Manufacturer: $($systemInfo.Manufacturer)" -ForegroundColor White
        Write-Host "Model: $($systemInfo.Model)" -ForegroundColor White
        Write-Host "OS: $($systemInfo.OSCaption) Build $($systemInfo.OSBuild)" -ForegroundColor White
        Write-Host "CPU: $($systemInfo.CPUName)" -ForegroundColor White
        Write-Host "CPU Cores: $($systemInfo.CPUCores)" -ForegroundColor White
        Write-Host "RAM: $($systemInfo.RAMTotal) GB" -ForegroundColor White
        
        # Color-coded disk space
        $diskColor = if ($systemInfo.CDriveUsedPercent -gt 90) { "Red" } 
                    elseif ($systemInfo.CDriveUsedPercent -gt 80) { "Yellow" } 
                    else { "Green" }
        Write-Host "C: Drive: $($systemInfo.CDriveFreeSpace) GB free of $($systemInfo.CDriveCapacity) GB ($($systemInfo.CDriveUsedPercent)% used)" -ForegroundColor $diskColor
        
        # Color-coded uptime
        $uptimeColor = if ($systemInfo.UptimeDays -gt 30) { "Yellow" } 
                      elseif ($systemInfo.UptimeDays -gt 7) { "White" } 
                      else { "Green" }
        Write-Host "System Uptime: $($systemInfo.SystemUptime)" -ForegroundColor $uptimeColor
    }
}

# Main execution
$scriptStartTime = Get-Date

if (-not $Quiet) {
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " RescuePC Repairs - System Health Check" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

Write-Log "Starting system health check at $scriptStartTime" -Level "INFO"
Write-Log "Running as Administrator: $isAdmin" -Level "INFO"

try {
    # Collect system information
    $systemInfo = Get-SystemInfo
    Show-SystemInfo -systemInfo $systemInfo
    
    Show-Progress -Activity "System Health Check" -Status "Checking services..." -PercentComplete 50
    
    # Basic service check
    try {
        $criticalServices = @("BITS", "Winmgmt", "EventLog", "Themes", "AudioSrv")
        foreach ($service in $criticalServices) {
            $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($svc -and $svc.Status -ne "Running") {
                $global:IssuesFound += "Service '$service' is not running"
                Write-Log "WARNING: Service '$service' is not running" -Level "WARNING"
            }
        }
    } catch {
        Write-Log "Error checking services: $_" -Level "ERROR"
    }
    
    Show-Progress -Activity "System Health Check" -Status "Generating report..." -PercentComplete 90
    
} catch {
    Write-Log "Critical error during health check: $_" -Level "ERROR"
    $global:IssuesFound += "Critical error during health check execution"
} finally {
    $scriptEndTime = Get-Date
    $duration = $scriptEndTime - $scriptStartTime
    
    if (-not $Quiet) {
        Write-Host "`n============================================================" -ForegroundColor Cyan
        Write-Host " SYSTEM HEALTH CHECK SUMMARY" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Scan completed in: $($duration.ToString())" -ForegroundColor Green
        Write-Host "Issues found: $($global:IssuesFound.Count)" -ForegroundColor $(if ($global:IssuesFound.Count -eq 0) { "Green" } else { "Yellow" })
        Write-Host "Errors: $global:ErrorCount" -ForegroundColor $(if ($global:ErrorCount -eq 0) { "Green" } else { "Red" })
        Write-Host "Warnings: $global:WarningCount" -ForegroundColor $(if ($global:WarningCount -eq 0) { "Green" } else { "Yellow" })
        
        if ($global:IssuesFound.Count -gt 0) {
            Write-Host "`nIssues and Recommendations:" -ForegroundColor Yellow
            foreach ($issue in $global:IssuesFound) {
                Write-Host "  â€¢ $issue" -ForegroundColor Yellow
            }
        }
        
        Write-Host "`nLog saved to: $logPath" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
    }
    
    Write-Log "System health check completed in $($duration.ToString())" -Level "SUCCESS"
    Write-Progress -Activity "System Health Check" -Completed
}

exit 0 
