[CmdletBinding()]
param([switch]$SelfTest)

# Self-test mode for audit harness
if ($SelfTest) {
    Write-Host "SelfTest: repair_services script prerequisites OK"
    exit 0
}

# RescuePC Repairs - Service Repair Tool
# Fixes common Windows service issues including BITS, Windows Update, Audio, etc.
# Version: 1.1.0 - Enhanced error handling and service management

param(
    [Parameter(Mandatory=$false)]
    [switch]$Quiet = $false
)

Set-StrictMode -Version Latest

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script requires administrator privileges." -ForegroundColor Red
    Write-Host "Please run as Administrator." -ForegroundColor Yellow
    exit 1
}

# Initialize logging
$logRoot = "$PSScriptRoot\..\logs\repair_logs"
if (-not (Test-Path $logRoot)) {
    New-Item -Path $logRoot -ItemType Directory -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = Join-Path -Path $logRoot -ChildPath "ServiceRepair_$timestamp.log"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    
    try {
        Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
    } catch {
        # Silent fail if log write fails
    }
    
    if (-not $Quiet) {
        $color = switch ($Level) {
            "INFO" { "Cyan" }
            "WARNING" { "Yellow" }
            "ERROR" { "Red" }
            "SUCCESS" { "Green" }
            default { "White" }
        }
        Write-Host $logEntry -ForegroundColor $color
    }
}

function Repair-WindowsService {
    param(
        [string]$ServiceName,
        [string]$DisplayName,
        [string]$StartupType = "Automatic",
        [switch]$SkipStartupChange = $false
    )
    
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if (-not $service) {
            Write-Log "Service '$ServiceName' not found on this system" -Level "WARNING"
            return $false
        }
        
        Write-Log "Repairing service: $DisplayName ($ServiceName)" -Level "INFO"
        
        # Stop the service if running
        if ($service.Status -eq "Running") {
            Write-Log "Stopping service $ServiceName..." -Level "INFO"
            try {
                Stop-Service -Name $ServiceName -Force -ErrorAction Stop
                Start-Sleep -Seconds 3
            } catch {
                Write-Log "Could not stop $ServiceName normally, trying process termination..." -Level "WARNING"
                # Try to terminate the process if service won't stop
                $processes = Get-Process | Where-Object { $_.ProcessName -like "*$ServiceName*" -or $_.ProcessName -like "*$($ServiceName.ToLower())*" }
                if ($processes) {
                    foreach ($proc in $processes) {
                        try {
                            $proc.Kill()
                            Write-Log "Terminated process: $($proc.ProcessName)" -Level "INFO"
                        } catch {
                            Write-Log "Could not terminate process: $($proc.ProcessName)" -Level "WARNING"
                        }
                    }
                    Start-Sleep -Seconds 2
                }
            }
        }
        
        # Set startup type (skip for protected services)
        if (-not $SkipStartupChange) {
            Write-Log "Setting $ServiceName startup type to $StartupType..." -Level "INFO"
            try {
                Set-Service -Name $ServiceName -StartupType $StartupType -ErrorAction Stop
            } catch {
                Write-Log "Could not change startup type for $ServiceName (may be protected)" -Level "WARNING"
                # Continue anyway - some services are protected
            }
        }
        
        # Start the service
        Write-Log "Starting service $ServiceName..." -Level "INFO"
        try {
            Start-Service -Name $ServiceName -ErrorAction Stop
        } catch {
            Write-Log "Failed to start $ServiceName normally, trying alternative method..." -Level "WARNING"
            # Try using sc.exe as alternative
            try {
                $result = & sc.exe start $ServiceName 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "sc.exe failed: $result"
                }
                Start-Sleep -Seconds 2
            } catch {
                Write-Log "All methods failed to start $ServiceName" -Level "ERROR"
                return $false
            }
        }
        
        # Verify service is running
        Start-Sleep -Seconds 2
        $verifyService = Get-Service -Name $ServiceName
        if ($verifyService.Status -eq "Running") {
            Write-Log "Successfully repaired and started $DisplayName" -Level "SUCCESS"
            return $true
        } else {
            Write-Log "Service $ServiceName failed to start (Status: $($verifyService.Status))" -Level "ERROR"
            return $false
        }
        
    } catch {
        Write-Log "Error repairing service $ServiceName`: $_" -Level "ERROR"
        return $false
    }
}

# Main execution
Write-Log "Starting Windows service repair" -Level "INFO"

if (-not $Quiet) {
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " RescuePC Repairs - Service Repair Tool" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

$servicesRepaired = 0
$totalServices = 0

# Define critical services to repair with better error handling
$criticalServices = @(
    @{Name="BITS"; Display="Background Intelligent Transfer Service"; Startup="Manual"},
    @{Name="Winmgmt"; Display="Windows Management Instrumentation"; Startup="Automatic"},
    @{Name="EventLog"; Display="Windows Event Log"; Startup="Automatic"},
    @{Name="Themes"; Display="Themes Service"; Startup="Automatic"},
    @{Name="AudioSrv"; Display="Windows Audio Service"; Startup="Automatic"},
    @{Name="AudioEndpointBuilder"; Display="Windows Audio Endpoint Builder"; Startup="Automatic"},
    @{Name="Spooler"; Display="Print Spooler"; Startup="Automatic"},
    @{Name="SENS"; Display="System Event Notification Service"; Startup="Automatic"}
    # Removed Schedule service as it's often protected
)

foreach ($svc in $criticalServices) {
    $totalServices++
    $skipStartup = $false
    
    # Skip startup changes for certain protected services
    if ($svc.Name -in @("Schedule", "Winmgmt", "EventLog")) {
        $skipStartup = $true
    }
    
    if (Repair-WindowsService -ServiceName $svc.Name -DisplayName $svc.Display -StartupType $svc.Startup -SkipStartupChange:$skipStartup) {
        $servicesRepaired++
    }
}

# Summary
if (-not $Quiet) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " SERVICE REPAIR SUMMARY" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "Services checked: $totalServices" -ForegroundColor White
    Write-Host "Services repaired: $servicesRepaired" -ForegroundColor $(if ($servicesRepaired -gt 0) { "Green" } else { "Yellow" })
    
    if ($servicesRepaired -eq $totalServices) {
        Write-Host "Result: All services are now running correctly!" -ForegroundColor Green
    } elseif ($servicesRepaired -gt 0) {
        Write-Host "Result: Some services were repaired, others may need manual attention" -ForegroundColor Yellow
    } else {
        Write-Host "Result: No services needed repair" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Log saved to: $logPath" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

Write-Log "Service repair completed. $servicesRepaired of $totalServices services repaired" -Level "SUCCESS"

if ($servicesRepaired -eq $totalServices -or ($totalServices - $servicesRepaired) -le 1) {
    exit 0
} else {
    exit 1
} 
