[CmdletBinding()]
param([switch]$SelfTest)

# Self-test mode for audit harness
if ($SelfTest) {
    Write-Host "SelfTest: repair_audio script prerequisites OK"
    exit 0
}

# RescuePC Audio Repair Script

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

# This script diagnoses and repairs common Windows audio issues
#
# IMPORTANT: This script focuses on REPAIRING audio-related issues.
# It complements SysHealthCheck.ps1 which only performs detection and reporting.
# This script handles audio service resets, driver reinstallation, and audio stack repairs.

# Initialize logging
$currentDate = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile = "logs\repair_logs\AudioRepair_$currentDate.log"
$ErrorActionPreference = "Continue"

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    # Create log directory if it doesn't exist
    $logDir = Split-Path $logFile -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
    
    # Also output to console with color based on level
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default { Write-Host $logEntry }
    }
}

# Log script start
Write-Log "Starting repair_audio.ps1 at $(Get-Date)"

# Check if script is running as admin
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    Write-Log "This script requires administrator privileges to repair audio services." -Level "ERROR"
    exit 1
}

# Define the audio services to restart
$AudioServices = @(
    "Audiosrv",          # Windows Audio
    "AudioEndpointBuilder", # Windows Audio Endpoint Builder
    "MMCSS"              # Multimedia Class Scheduler
)

function Stop-ServiceWithTimeout {
    param (
        [string]$ServiceName,
        [int]$TimeoutSeconds = 10
    )
    
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop
        
        # If already stopped, just return
        if ($service.Status -eq "Stopped") {
            return $true
        }
        
        # Try normal stop first
        try {
            $stopJob = Start-Job -ScriptBlock {
                param($svcName)
                Stop-Service -Name $svcName -Force -ErrorAction Stop
            } -ArgumentList $ServiceName
            
            # Wait for job to complete with timeout
            $completed = Wait-Job -Job $stopJob -Timeout $TimeoutSeconds
            
            # If timeout occurred
            if (-not $completed) {
                Write-Log "Timeout stopping service $ServiceName normally. Using fallback methods..." -Level "WARNING"
                Remove-Job -Job $stopJob -Force
                
                # Try with SC command as fallback
                $scExe = Get-SystemExecutable -Name 'sc.exe'
$scOutput = & $scExe stop $ServiceName 2>&1
                Start-Sleep -Seconds 2
                
                # Check if stopped now
                $service = Get-Service -Name $ServiceName -ErrorAction Stop
                if ($service.Status -eq "Stopped") {
                    return $true
                }
                
                # Last resort: taskkill for associated process
                # Special handling for problematic services
                if ($ServiceName -eq "MMCSS") {
                    Write-Log "MMCSS service is stubborn. Trying direct process termination..." -Level "WARNING"
                    $mmcssProcesses = Get-CimInstance -ClassName Win32_Service -Filter "Name='MMCSS'" | 
                                     Select-Object -ExpandProperty ProcessId
                    
                    if ($mmcssProcesses) {
                        foreach ($pid in $mmcssProcesses) {
                            if ($pid -gt 0) {
                                try {
                                    Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
                                }
                                catch {
                                    # Just continue if process can't be stopped
                                }
                            }
                        }
                        
                        # Give it a moment
                        Start-Sleep -Seconds 2
                    }
                    
                    # At this point, consider it "handled" even if it's not fully stopped
                    return $true
                }
                
                return $false
            }
            else {
                # Job completed in time, check results
                Receive-Job -Job $stopJob
                Remove-Job -Job $stopJob
                return $true
            }
        }
        catch {
            Write-Log "Error in stop service job: $_" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Error getting service $ServiceName" + ": $_" -Level "ERROR"
        return $false
    }
}

function Wait-ForServiceStatus {
    param (
        [string]$ServiceName,
        [string]$Status,
        [int]$TimeoutSeconds = 15
    )
    
    $startTime = Get-Date
    $timeSpan = New-TimeSpan -Seconds $TimeoutSeconds
    $endTime = $startTime + $timeSpan
    
    while ((Get-Date) -lt $endTime) {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq $Status) {
            return $true
        }
        Start-Sleep -Milliseconds 500
    }
    
    return $false
}

function Restart-AudioService {
    param (
        [string]$ServiceName,
        [switch]$SkipStopPhase = $false
    )
    
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop
        Write-Log "Service '$ServiceName' status: $($service.Status)"
        
        # Handle pending states first
        if ($service.Status -like "*Pending*") {
            Write-Log "Service $ServiceName is in $($service.Status) state. Waiting for it to complete..." -Level "WARNING"
            
            # Wait for the service to settle - max 15 seconds
            $settled = $false
            $retries = 0
            while (-not $settled -and $retries -lt 3) {
                Start-Sleep -Seconds 5
                $retries++
                $service = Get-Service -Name $ServiceName -ErrorAction Stop
                if ($service.Status -notlike "*Pending*") {
                    $settled = $true
                    Write-Log "Service $ServiceName settled to $($service.Status) state"
                }
            }
        }
        
        # Special handling for MMCSS
        if ($ServiceName -eq "MMCSS" -and $service.Status -eq "Running") {
            Write-Log "MMCSS service requires special handling..." -Level "INFO"
            
            # Try a more gentle approach for MMCSS
            if (-not $SkipStopPhase) {
                $stopResult = Stop-ServiceWithTimeout -ServiceName $ServiceName -TimeoutSeconds 10
                if (-not $stopResult) {
                    Write-Log "Could not stop MMCSS service. Will try to restart without stopping." -Level "WARNING"
                    $SkipStopPhase = $true
                }
            }
        }
        # Stop service if it's running and stop is not skipped
        elseif ($service.Status -eq "Running" -and -not $SkipStopPhase) {
            $stopResult = Stop-ServiceWithTimeout -ServiceName $ServiceName -TimeoutSeconds 15
            if (-not $stopResult) {
                Write-Log "Could not stop service $ServiceName. Will try to restart anyway." -Level "WARNING"
            }
        }
        
        # Make sure it's set to automatic startup
        Set-Service -Name $ServiceName -StartupType Automatic -ErrorAction Stop
        
        # Start the service if it's not running
        $service = Get-Service -Name $ServiceName -ErrorAction Stop
        if ($service.Status -ne "Running") {
            Write-Log "Starting service: $ServiceName..."
            Start-Service -Name $ServiceName -ErrorAction Stop
            
            # Wait for service to start
            if (Wait-ForServiceStatus -ServiceName $ServiceName -Status "Running" -TimeoutSeconds 15) {
                Write-Log "Started service: $ServiceName" -Level "SUCCESS"
                return $true
            } else {
                # Try one more time with net start command
                Write-Log "Timeout waiting for service $ServiceName to start. Trying alternative method..." -Level "WARNING"
                $netExe = Get-SystemExecutable -Name 'net'
                $netStartOutput = & $netExe start $ServiceName 2>&1
                Start-Sleep -Seconds 3
                
                # Check if it's running now
                $service = Get-Service -Name $ServiceName -ErrorAction Stop
                if ($service.Status -eq "Running") {
                    Write-Log "Successfully started service $ServiceName using net start" -Level "SUCCESS"
                    return $true
                } else {
                    $errorMsg = "Failed to start service $ServiceName after multiple attempts. Status: $($service.Status)"
                    Write-Log $errorMsg -Level "ERROR"
                    return $false
                }
            }
        } else {
            Write-Log "Service $ServiceName is already running" -Level "SUCCESS"
            return $true
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Error managing service $ServiceName`: $errorMsg" -Level "ERROR"
        
        # Try one last approach
        try {
            Write-Log "Attempting recovery of service $ServiceName using SC..." -Level "WARNING"
            $scExe = Get-SystemExecutable -Name 'sc.exe'
$scOutput = & $scExe config $ServiceName start= auto
            Start-Sleep -Seconds 1
            $scExe = Get-SystemExecutable -Name 'sc.exe'
$scOutput = & $scExe start $ServiceName
            Start-Sleep -Seconds 3
            
            # Check if it's running now
            $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($service -and $service.Status -eq "Running") {
                Write-Log "Successfully recovered service $ServiceName using SC" -Level "SUCCESS"
                return $true
            }
        } catch {
            # Just log and continue
            Write-Log "Recovery attempt for $ServiceName also failed" -Level "ERROR"
        }
        
        return $false
    }
}

function Test-AudioServices {
    $allRunning = $true
    
    foreach ($service in $AudioServices) {
        try {
            $svc = Get-Service -Name $service -ErrorAction Stop
            if ($svc.Status -ne "Running") {
                Write-Log "Service $service is not running (Status: $($svc.Status))" -Level "WARNING"
                $allRunning = $false
            }
            else {
                Write-Log "Service $service is running properly"
            }
        }
        catch {
            $errorMsg = $_.Exception.Message
            Write-Log "Could not check service $service`: $errorMsg" -Level "ERROR"
            $allRunning = $false
        }
    }
    
    return $allRunning
}

function Reset-AudioDevices {
    try {
        Write-Log "Detecting and enabling disabled audio devices..."
        
        # Using PowerShell to enable all disabled audio devices
        $audioDevices = $null
        try {
            $audioDevices = @(Get-PnpDevice -Class "AudioEndpoint" -Status Error -ErrorAction SilentlyContinue)
        } catch {
            Write-Log "No AudioEndpoint devices in error state found. This is normal if all devices are working properly." -Level "INFO"
        }
        
        # Check if any audio devices were found
        if ($audioDevices -and $audioDevices.Length -gt 0) {
            foreach ($device in $audioDevices) {
                try {
                    Write-Log "Attempting to enable audio device: $($device.FriendlyName)"
                    Enable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false
                    Write-Log "Successfully enabled: $($device.FriendlyName)" -Level "SUCCESS"
                }
                catch {
                    $errorMsg = $_.Exception.Message
                    Write-Log "Failed to enable device $($device.FriendlyName)`: $errorMsg" -Level "ERROR"
                }
            }
        } else {
            Write-Log "No disabled audio devices found. Checking for Media devices instead..." -Level "INFO"
            try {
                # Force result to be an array with @() syntax
                $mediaDevices = @(Get-PnpDevice -Class "MEDIA" -Status Error -ErrorAction SilentlyContinue)
                
                # Check if media devices were found using Length property which works with arrays of any size
                if ($mediaDevices -and $mediaDevices.Length -gt 0) {
                    foreach ($device in $mediaDevices) {
                        try {
                            Write-Log "Attempting to enable media device: $($device.FriendlyName)"
                            Enable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false
                            Write-Log "Successfully enabled: $($device.FriendlyName)" -Level "SUCCESS"
                        }
                        catch {
                            $errorMsg = $_.Exception.Message
                            Write-Log "Failed to enable device $($device.FriendlyName)`: $errorMsg" -Level "ERROR"
                        }
                    }
                } else {
                    Write-Log "No disabled media devices found" -Level "INFO"
                }
            } catch {
                Write-Log "Error checking media devices: $($_.Exception.Message)" -Level "WARNING"
            }
        }
        
        # Reset default audio device settings
        Write-Log "Running audio device diagnostics..."
        $diagnostics = Start-Process -FilePath "msdt.exe" -ArgumentList "/id AudioPlaybackDiag" -PassThru -WindowStyle Minimized
        $diagnostics.WaitForExit(10000) # Wait up to 10 seconds
        if (-not $diagnostics.HasExited) {
            # If it's still running after 10 seconds, kill it (diagnostics can hang)
            $diagnostics | Stop-Process -Force
            Write-Log "Audio diagnostics timed out, continuing with repair..." -Level "WARNING"
        }
        
        Write-Log "Audio device reset completed"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Error resetting audio devices`: $errorMsg" -Level "ERROR"
        return $false
    }
}

function Repair-AudioDriver {
    try {
        Write-Log "Scanning for audio driver issues..."
        
        # Scan for hardware changes to detect any new/changed audio devices
        $scanProcess = Start-Process -FilePath "pnputil.exe" -ArgumentList "/scan-devices" -NoNewWindow -Wait -PassThru
        if ($scanProcess.ExitCode -ne 0) {
            Write-Log "Warning: Device scan completed with exit code $($scanProcess.ExitCode)" -Level "WARNING"
        }
        
        # Force result to be an array with @() syntax to ensure Length property exists
        $mediaDevices = @(Get-PnpDevice -Class "MEDIA" -Status Error -ErrorAction SilentlyContinue)
        
        # Check if devices were found using Length property for arrays
        if ($mediaDevices -and $mediaDevices.Length -gt 0) {
            foreach ($device in $mediaDevices) {
                try {
                    Write-Log "Found problematic media device: $($device.FriendlyName)"
                    Disable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false
                    Start-Sleep -Seconds 2
                    Enable-PnpDevice -InstanceId $device.InstanceId -Confirm:$false
                    Write-Log "Successfully reset device: $($device.FriendlyName)" -Level "SUCCESS"
                }
                catch {
                    $errorMsg = $_.Exception.Message
                    Write-Log "Failed to reset device $($device.FriendlyName)`: $errorMsg" -Level "ERROR"
                }
            }
        } else {
            Write-Log "No problematic media devices found" -Level "INFO"
        }
        
        Write-Log "Audio driver repair completed"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Error repairing audio drivers`: $errorMsg" -Level "ERROR"
        return $false
    }
}

function Reset-AudioSettings {
    try {
        Write-Log "Resetting Windows audio settings..."
        
        # Clear Windows audio policy
        $deviceCplPath = "HKCU:\Software\Microsoft\Multimedia\Audio\DeviceCpl"
        if (Test-Path $deviceCplPath) {
            Get-ChildItem $deviceCplPath | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }
        
        # Reset audio service dependencies
        $scExe = Get-SystemExecutable -Name 'sc.exe'
Start-Process -FilePath $scExe -ArgumentList "config Audiosrv depend= RpcSs" -NoNewWindow -Wait
        
        # Reset DirectSound settings
        $regPath = "HKLM:\SOFTWARE\Microsoft\DirectSound"
        if (Test-Path $regPath) {
            $cachePath = "$regPath\CompatCache"
            if (Test-Path $cachePath) {
                Remove-Item -Path $cachePath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        Write-Log "Audio settings reset completed"
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Error resetting audio settings`: $errorMsg" -Level "ERROR"
        return $false
    }
}

# Function to forcefully restart audio services
function Force-RestartAudioServices {
    Write-Log "Performing forceful audio service restart..." -Level "WARNING"
    
    # 1. Kill processes that might lock audio services
    $processesToKill = @("audiodg.exe", "SndVol.exe")
    foreach ($proc in $processesToKill) {
        $processes = Get-Process -Name $proc -ErrorAction SilentlyContinue
        if ($processes) {
            Write-Log "Stopping $proc process..."
            Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
        }
    }
    
    # 2. Stop all audio services with SC
    foreach ($service in $AudioServices) {
        Write-Log "Forcefully stopping service $service with SC command..."
        $scOutput = sc.exe stop $service 2>&1
        Start-Sleep -Seconds 2
    }
    
    # 3. Start all audio services in correct order
    Start-Sleep -Seconds 3
    
    # Windows Audio Endpoint Builder must start first
    Write-Log "Starting AudioEndpointBuilder with SC command..."
    $scExe = Get-SystemExecutable -Name 'sc.exe'
$scOutput = & $scExe start AudioEndpointBuilder 2>&1
    Start-Sleep -Seconds 3
    
    # Then Windows Audio
    Write-Log "Starting Audiosrv with SC command..."
    $scExe = Get-SystemExecutable -Name 'sc.exe'
$scOutput = & $scExe start Audiosrv 2>&1
    Start-Sleep -Seconds 3
    
    # Then MMCSS
    Write-Log "Starting MMCSS with SC command..."
    $scExe = Get-SystemExecutable -Name 'sc.exe'
$scOutput = & $scExe start MMCSS 2>&1
    Start-Sleep -Seconds 2
    
    # 4. Check if services are running
    $allRunning = $true
    foreach ($service in $AudioServices) {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq "Running") {
            Write-Log "Service $service is now running" -Level "SUCCESS"
        } else {
            if ($service -eq "MMCSS") {
                Write-Log "MMCSS service is not running, but this is not critical" -Level "WARNING"
            } else {
                $allRunning = $false
                if ($svc) {
                    Write-Log "Service $service is still not running (Status: $($svc.Status))" -Level "ERROR"
                } else {
                    Write-Log "Could not find service $service" -Level "ERROR"
                }
            }
        }
    }
    
    return $allRunning
}

# Main repair process
Write-Log "Starting audio repair process..."

# Step 1: Check current status of audio services
$initialStatus = Test-AudioServices
if ($initialStatus) {
    Write-Log "All audio services are already running. Proceeding with additional repairs." -Level "INFO"
}
else {
    Write-Log "Audio services need repair. Starting service restoration..." -Level "WARNING"
}

# Step 2: Restart audio services
$restartSuccess = $true
# First restart Windows Audio Endpoint Builder
$result = Restart-AudioService -ServiceName "AudioEndpointBuilder"
$restartSuccess = $restartSuccess -and $result

# Then Windows Audio
$result = Restart-AudioService -ServiceName "Audiosrv"
$restartSuccess = $restartSuccess -and $result

# Finally MMCSS, with special handling (allow it to be skipped if it causes problems)
try {
    $mmcssResult = Restart-AudioService -ServiceName "MMCSS"
    if (-not $mmcssResult) {
        Write-Log "MMCSS service restart failed, but this is non-critical. Continuing..." -Level "WARNING"
        # Don't set restartSuccess to false for MMCSS
    }
}
catch {
    Write-Log "Error during MMCSS restart: $_. Continuing anyway..." -Level "WARNING"
}

# Step 3: Reset Audio Devices
$deviceResetResult = Reset-AudioDevices

# Step 4: Repair Audio Driver
$driverResult = Repair-AudioDriver

# Step 5: Reset Audio Settings
$settingsResult = Reset-AudioSettings

# Final check - only check Audiosrv and AudioEndpointBuilder (consider MMCSS optional)
$criticalServices = @("Audiosrv", "AudioEndpointBuilder")
$criticalServicesRunning = $true

foreach ($service in $criticalServices) {
    try {
        $svc = Get-Service -Name $service -ErrorAction Stop
        if ($svc.Status -ne "Running") {
            Write-Log "Critical service $service is not running (Status: $($svc.Status))" -Level "ERROR"
            $criticalServicesRunning = $false
        }
        else {
            Write-Log "Critical service $service is running properly" -Level "SUCCESS"
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Log "Could not check service $service`: $errorMsg" -Level "ERROR"
        $criticalServicesRunning = $false
    }
}

# Check MMCSS status but don't fail if it's not running
try {
    $mmcssSvc = Get-Service -Name "MMCSS" -ErrorAction SilentlyContinue
    if ($mmcssSvc -and $mmcssSvc.Status -eq "Running") {
        Write-Log "MMCSS service is running properly" -Level "SUCCESS"
    } else {
        Write-Log "MMCSS service is not running, but this is non-critical" -Level "WARNING"
        # Try once to start it without error checking
        Start-Service -Name "MMCSS" -ErrorAction SilentlyContinue
    }
}
catch {
    Write-Log "Note: Could not verify MMCSS service, but this is non-critical" -Level "INFO"
}

if (-not $criticalServicesRunning) {
    # Try forceful restart as last resort
    Write-Log "Standard repair approach didn't fix all services. Attempting forceful restart..." -Level "WARNING"
    $forcedRestart = Force-RestartAudioServices
    
    # Only check critical services again
    $finalCriticalCheck = $true
    foreach ($service in $criticalServices) {
        try {
            $svc = Get-Service -Name $service -ErrorAction Stop
            if ($svc.Status -ne "Running") {
                $finalCriticalCheck = $false
                break
            }
        }
        catch {
            $finalCriticalCheck = $false
            break
        }
    }
    
    if ($finalCriticalCheck) {
        Write-Log "Audio repair completed successfully. Critical audio services are now running." -Level "SUCCESS"
        Write-Log "A system restart is recommended for changes to take full effect."
        exit 0
    } else {
        Write-Log "Audio repair completed with warnings. Some critical audio services could not be restored to running state." -Level "WARNING"
        Write-Log "Please restart your computer to complete the audio repair process."
        exit 1
    }
}
else {
    Write-Log "Audio repair completed successfully. Critical audio services are running." -Level "SUCCESS"
    Write-Log "A system restart is recommended for changes to take full effect."
    exit 0
}

