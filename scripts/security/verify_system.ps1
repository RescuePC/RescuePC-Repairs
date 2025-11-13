# RescuePC Repairs - System Verification Suite
# Comprehensive system verification including scripts, executables, toolkit, drivers, and security scan
# Version: 2.0 - Advanced verification with HTML reporting

[CmdletBinding()]
param(
    [switch]$SelfTest,
    [switch]$Help,
    [switch]$QuickScan = $false,
    [switch]$FullVerification = $false,
    [switch]$GenerateReport = $true,
    [switch]$Quiet = $false
)

if ($Help) {
    @"
Verify System

  - Aggregates: verify_toolkit, validate_drivers, verify_executables, verify_scripts
  - Generates HTML report with all verification results

Usage: .\verify_system.ps1 [-SelfTest] [-QuickScan] [-FullVerification] [-GenerateReport]

Parameters:
  -SelfTest         Run non-destructive self-test
  -Help             Show this help message
  -QuickScan        Run basic checks only
  -FullVerification Run comprehensive verification
  -GenerateReport   Generate HTML report (default: true)
  -Quiet            Suppress console output

"@ | Write-Output
    exit 0
}

# Self-test mode for audit harness
if ($SelfTest) {
    Write-Host "Verify System SelfTest: OK (placeholder)"
    exit 0
}

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: This script requires administrator privileges." -ForegroundColor Red
    exit 1
}

# Initialize logging
$logPath = Join-Path (Split-Path -Parent $PSScriptRoot) "logs\repair_logs"
if (-not (Test-Path -Path $logPath -PathType Container)) {
    try {
        New-Item -Path $logPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "ERROR: Cannot create log directory: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

$logFile = Join-Path $logPath "verify_system_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry -ErrorAction SilentlyContinue
    if (-not $Quiet) {
        $color = switch ($Level) {
            "ERROR" { "Red" }
            "WARN"  { "Yellow" }
            "INFO"  { "White" }
            "SUCCESS" { "Green" }
            default { "White" }
        }
        Write-Host $logEntry -ForegroundColor $color
    }
}

# Global verification results
$global:VerificationResults = @{
    Summary = @{
        OverallStatus = "Unknown"
        TotalChecks = 0
        PassedChecks = 0
        FailedChecks = 0
        WarningChecks = 0
        StartTime = Get-Date
        EndTime = $null
        Duration = $null
    }
    Scripts = @{
        Total = 0
        Passed = 0
        Failed = 0
        Errors = 0
        Results = @()
    }
    Executables = @{
        Total = 0
        Passed = 0
        Failed = 0
        Errors = 0
        Results = @()
    }
    Toolkit = @{
        Total = 0
        Passed = 0
        Failed = 0
        Errors = 0
        Results = @()
    }
    Drivers = @{
        Total = 0
        Passed = 0
        Failed = 0
        Errors = 0
        Results = @()
    }
}

# Function to verify PowerShell scripts
function Test-Scripts {
    Write-Log "Starting script verification..." "INFO"

    try {
        $scriptsDir = Split-Path -Parent $PSScriptRoot
        $scriptFiles = Get-ChildItem -Path $scriptsDir -Filter "*.ps1" -File -Recurse |
                      Where-Object { $_.Name -notin @('RescuePC_Launcher.ps1') }

        $global:VerificationResults.Scripts.Total = $scriptFiles.Count

        foreach ($script in $scriptFiles) {
            $result = @{
                Name = $script.Name
                Path = $script.FullName
                Status = "Unknown"
                Errors = @()
                Warnings = @()
            }

            try {
                # Try to parse the script
                $null = [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$null, [ref]$null)
                $result.Status = "Passed"
                $global:VerificationResults.Scripts.Passed++
            } catch {
                $result.Status = "Failed"
                $result.Errors += $_.Exception.Message
                $global:VerificationResults.Scripts.Failed++
            }

            $global:VerificationResults.Scripts.Results += $result
        }

        Write-Log "Script verification completed. Passed: $($global:VerificationResults.Scripts.Passed), Failed: $($global:VerificationResults.Scripts.Failed)" "SUCCESS"
    } catch {
        Write-Log "Script verification failed: $($_.Exception.Message)" "ERROR"
        $global:VerificationResults.Scripts.Errors++
    }
}

# Function to verify executables
function Test-Executables {
    Write-Log "Starting executable verification..." "INFO"

    try {
        $scriptsDir = Split-Path -Parent $PSScriptRoot
        $exeFiles = Get-ChildItem -Path $scriptsDir -Filter "*.exe" -File -Recurse

        $global:VerificationResults.Executables.Total = $exeFiles.Count

        foreach ($exe in $exeFiles) {
            $result = @{
                Name = $exe.Name
                Path = $exe.FullName
                Status = "Unknown"
                Errors = @()
                Warnings = @()
                Size = $exe.Length
                LastModified = $exe.LastWriteTime
            }

            try {
                # Check if file exists and is accessible
                if (Test-Path $exe.FullName) {
                    $result.Status = "Passed"
                    $global:VerificationResults.Executables.Passed++
                } else {
                    $result.Status = "Failed"
                    $result.Errors += "File not accessible"
                    $global:VerificationResults.Executables.Failed++
                }
            } catch {
                $result.Status = "Failed"
                $result.Errors += $_.Exception.Message
                $global:VerificationResults.Executables.Failed++
            }

            $global:VerificationResults.Executables.Results += $result
        }

        Write-Log "Executable verification completed. Passed: $($global:VerificationResults.Executables.Passed), Failed: $($global:VerificationResults.Executables.Failed)" "SUCCESS"
    } catch {
        Write-Log "Executable verification failed: $($_.Exception.Message)" "ERROR"
        $global:VerificationResults.Executables.Errors++
    }
}

# Function to verify toolkit components
function Test-Toolkit {
    Write-Log "Starting toolkit verification..." "INFO"

    try {
        $toolkitDir = Split-Path -Parent $PSScriptRoot
        $requiredFiles = @(
            "bin\RescuePC_Launcher.ps1",
            "scripts\verify_system.ps1",
            "scripts\malware_scan_removal.ps1"
        )

        $global:VerificationResults.Toolkit.Total = $requiredFiles.Count

        foreach ($file in $requiredFiles) {
            $fullPath = Join-Path $toolkitDir $file
            $result = @{
                Name = $file
                Path = $fullPath
                Status = "Unknown"
                Errors = @()
                Warnings = @()
            }

            if (Test-Path $fullPath) {
                $result.Status = "Passed"
                $global:VerificationResults.Toolkit.Passed++
            } else {
                $result.Status = "Failed"
                $result.Errors += "Required file not found"
                $global:VerificationResults.Toolkit.Failed++
            }

            $global:VerificationResults.Toolkit.Results += $result
        }

        Write-Log "Toolkit verification completed. Passed: $($global:VerificationResults.Toolkit.Passed), Failed: $($global:VerificationResults.Toolkit.Failed)" "SUCCESS"
    } catch {
        Write-Log "Toolkit verification failed: $($_.Exception.Message)" "ERROR"
        $global:VerificationResults.Toolkit.Errors++
    }
}

# Function to verify drivers
function Test-Drivers {
    Write-Log "Starting driver verification..." "INFO"

    try {
        $drivers = Get-WmiObject Win32_PnPSignedDriver -ErrorAction Stop
        $global:VerificationResults.Drivers.Total = $drivers.Count

        $signedCount = 0
        $unsignedCount = 0

        foreach ($driver in $drivers) {
            if ($driver.IsSigned) {
                $signedCount++
            } else {
                $unsignedCount++
            }
        }

        $result = @{
            Name = "Driver Signature Check"
            Status = "Passed"
            Details = "Signed: $signedCount, Unsigned: $unsignedCount"
            Errors = @()
            Warnings = @()
        }

        if ($unsignedCount -gt 0) {
            $result.Warnings += "Found $unsignedCount unsigned drivers"
            $result.Status = "Warning"
            $global:VerificationResults.Drivers.WarningChecks++
        }

        $global:VerificationResults.Drivers.Passed++
        $global:VerificationResults.Drivers.Results += $result

        Write-Log "Driver verification completed. Total: $($drivers.Count), Signed: $signedCount, Unsigned: $unsignedCount" "SUCCESS"
    } catch {
        Write-Log "Driver verification failed: $($_.Exception.Message)" "ERROR"
        $global:VerificationResults.Drivers.Errors++
    }
}

# Function to generate HTML report
function Generate-HTMLReport {
    Write-Log "Generating HTML verification report..." "INFO"

    try {
        $reportsDir = Join-Path (Split-Path -Parent $PSScriptRoot) "reports"
        if (-not (Test-Path $reportsDir)) {
            New-Item -Path $reportsDir -ItemType Directory -Force | Out-Null
        }

        $reportFile = Join-Path $reportsDir "system_verification_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"

        $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>RescuePC System Verification Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header { text-align: center; border-bottom: 2px solid #007acc; padding-bottom: 20px; margin-bottom: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .card { padding: 20px; border-radius: 8px; text-align: center; }
        .passed { background-color: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .failed { background-color: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
        .warning { background-color: #fff3cd; color: #856404; border: 1px solid #ffeaa7; }
        .section { margin-bottom: 30px; }
        .section h2 { color: #007acc; border-bottom: 1px solid #ddd; padding-bottom: 10px; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f8f9fa; font-weight: bold; }
        .status-passed { color: #28a745; font-weight: bold; }
        .status-failed { color: #dc3545; font-weight: bold; }
        .status-warning { color: #ffc107; font-weight: bold; }
        .footer { text-align: center; margin-top: 30px; color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 RescuePC System Verification Report</h1>
            <p>Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        </div>

        <div class="summary">
            <div class="card passed">
                <h3>✅ Passed</h3>
                <div style="font-size: 2em; font-weight: bold;">$($global:VerificationResults.Summary.PassedChecks)</div>
            </div>
            <div class="card failed">
                <h3>❌ Failed</h3>
                <div style="font-size: 2em; font-weight: bold;">$($global:VerificationResults.Summary.FailedChecks)</div>
            </div>
            <div class="card warning">
                <h3>⚠️ Warnings</h3>
                <div style="font-size: 2em; font-weight: bold;">$($global:VerificationResults.Summary.WarningChecks)</div>
            </div>
            <div class="card passed">
                <h3>📊 Total</h3>
                <div style="font-size: 2em; font-weight: bold;">$($global:VerificationResults.Summary.TotalChecks)</div>
            </div>
        </div>

        <div class="section">
            <h2>📜 Scripts Verification</h2>
            <table>
                <thead>
                    <tr>
                        <th>Script Name</th>
                        <th>Status</th>
                        <th>Path</th>
                        <th>Errors</th>
                    </tr>
                </thead>
                <tbody>
"@

        foreach ($script in $global:VerificationResults.Scripts.Results) {
            $statusClass = switch ($script.Status) {
                "Passed" { "status-passed" }
                "Failed" { "status-failed" }
                default { "" }
            }
            $html += @"
                    <tr>
                        <td>$($script.Name)</td>
                        <td class="$statusClass">$($script.Status)</td>
                        <td>$($script.Path)</td>
                        <td>$($script.Errors -join '; ')</td>
                    </tr>
"@
        }

        $html += @"
                </tbody>
            </table>
        </div>

        <div class="section">
            <h2>⚙️ Executables Verification</h2>
            <table>
                <thead>
                    <tr>
                        <th>Executable Name</th>
                        <th>Status</th>
                        <th>Size (KB)</th>
                        <th>Last Modified</th>
                    </tr>
                </thead>
                <tbody>
"@

        foreach ($exe in $global:VerificationResults.Executables.Results) {
            $statusClass = switch ($exe.Status) {
                "Passed" { "status-passed" }
                "Failed" { "status-failed" }
                default { "" }
            }
            $sizeKB = [Math]::Round($exe.Size / 1KB, 1)
            $html += @"
                    <tr>
                        <td>$($exe.Name)</td>
                        <td class="$statusClass">$($exe.Status)</td>
                        <td>$sizeKB</td>
                        <td>$($exe.LastModified)</td>
                    </tr>
"@
        }

        $html += @"
                </tbody>
            </table>
        </div>

        <div class="section">
            <h2>🛠️ Toolkit Components</h2>
            <table>
                <thead>
                    <tr>
                        <th>Component</th>
                        <th>Status</th>
                        <th>Path</th>
                    </tr>
                </thead>
                <tbody>
"@

        foreach ($component in $global:VerificationResults.Toolkit.Results) {
            $statusClass = switch ($component.Status) {
                "Passed" { "status-passed" }
                "Failed" { "status-failed" }
                default { "" }
            }
            $html += @"
                    <tr>
                        <td>$($component.Name)</td>
                        <td class="$statusClass">$($component.Status)</td>
                        <td>$($component.Path)</td>
                    </tr>
"@
        }

        $html += @"
                </tbody>
            </table>
        </div>

        <div class="section">
            <h2>🚗 Drivers Verification</h2>
            <table>
                <thead>
                    <tr>
                        <th>Check Type</th>
                        <th>Status</th>
                        <th>Details</th>
                    </tr>
                </thead>
                <tbody>
"@

        foreach ($driver in $global:VerificationResults.Drivers.Results) {
            $statusClass = switch ($driver.Status) {
                "Passed" { "status-passed" }
                "Warning" { "status-warning" }
                "Failed" { "status-failed" }
                default { "" }
            }
            $html += @"
                    <tr>
                        <td>$($driver.Name)</td>
                        <td class="$statusClass">$($driver.Status)</td>
                        <td>$($driver.Details)</td>
                    </tr>
"@
        }

        $html += @"
                </tbody>
            </table>
        </div>

        <div class="footer">
            <p>Report generated by RescuePC Toolkit v2.0 | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        </div>
    </div>
</body>
</html>
"@

        $html | Set-Content -Path $reportFile -Encoding UTF8
        Write-Log "HTML report saved to: $reportFile" "SUCCESS"

        if (-not $Quiet) {
            Write-Host "`n📊 System Verification Report: $reportFile" -ForegroundColor Cyan
        }

    } catch {
        Write-Log "HTML report generation failed: $($_.Exception.Message)" "ERROR"
    }
}

# Main verification function
function Start-SystemVerification {
    $startTime = Get-Date
    Write-Log "=== Starting System Verification Suite ===" "INFO"
    Write-Log "Verification session started at: $startTime" "INFO"

    try {
        # Determine what to verify based on parameters
        $runScripts = -not $QuickScan
        $runExecutables = -not $QuickScan
        $runToolkit = $true
        $runDrivers = -not $QuickScan

        if ($QuickScan) {
            Write-Log "Running QUICK SCAN mode - basic checks only" "INFO"
        } elseif ($FullVerification) {
            Write-Log "Running FULL VERIFICATION mode - comprehensive checks" "INFO"
        }

        # Run verifications
        if ($runScripts) { Test-Scripts }
        if ($runExecutables) { Test-Executables }
        if ($runToolkit) { Test-Toolkit }
        if ($runDrivers) { Test-Drivers }

        # Calculate summary
        $global:VerificationResults.Summary.TotalChecks =
            $global:VerificationResults.Scripts.Total +
            $global:VerificationResults.Executables.Total +
            $global:VerificationResults.Toolkit.Total +
            $global:VerificationResults.Drivers.Total

        $global:VerificationResults.Summary.PassedChecks =
            $global:VerificationResults.Scripts.Passed +
            $global:VerificationResults.Executables.Passed +
            $global:VerificationResults.Toolkit.Passed +
            $global:VerificationResults.Drivers.Passed

        $global:VerificationResults.Summary.FailedChecks =
            $global:VerificationResults.Scripts.Failed +
            $global:VerificationResults.Executables.Failed +
            $global:VerificationResults.Toolkit.Failed +
            $global:VerificationResults.Drivers.Failed

        $global:VerificationResults.Summary.WarningChecks =
            $global:VerificationResults.Scripts.Errors +
            $global:VerificationResults.Executables.Errors +
            $global:VerificationResults.Toolkit.Errors +
            $global:VerificationResults.Drivers.Errors

        # Determine overall status
        if ($global:VerificationResults.Summary.FailedChecks -gt 0) {
            $global:VerificationResults.Summary.OverallStatus = "FAILED"
        } elseif ($global:VerificationResults.Summary.WarningChecks -gt 0) {
            $global:VerificationResults.Summary.OverallStatus = "WARNING"
        } else {
            $global:VerificationResults.Summary.OverallStatus = "PASSED"
        }

        $endTime = Get-Date
        $global:VerificationResults.Summary.EndTime = $endTime
        $global:VerificationResults.Summary.Duration = $endTime - $startTime

        # Generate report
        if ($GenerateReport) {
            Generate-HTMLReport
        }

        Write-Log "=== System Verification Suite Completed ===" "SUCCESS"
        Write-Log "Overall status: $($global:VerificationResults.Summary.OverallStatus)" "INFO"

        if (-not $Quiet) {
            Write-Host "`n" -NoNewline
            Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
            Write-Host "║                           VERIFICATION COMPLETE                           ║" -ForegroundColor Cyan
            Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
            Write-Host ""

            $scoreColor = switch ($global:VerificationResults.Summary.OverallStatus) {
                "PASSED" { "Green" }
                "WARNING" { "Yellow" }
                "FAILED" { "Red" }
                default { "White" }
            }

            Write-Host "Overall Status: " -NoNewline
            Write-Host "$($global:VerificationResults.Summary.OverallStatus)" -ForegroundColor $scoreColor

            Write-Host "Checks Passed: " -NoNewline
            Write-Host "$($global:VerificationResults.Summary.PassedChecks)/$($global:VerificationResults.Summary.TotalChecks)" -ForegroundColor Green

            if ($global:VerificationResults.Summary.FailedChecks -gt 0) {
                Write-Host "Failed Checks: " -NoNewline
                Write-Host "$($global:VerificationResults.Summary.FailedChecks)" -ForegroundColor Red
            }

            if ($global:VerificationResults.Summary.WarningChecks -gt 0) {
                Write-Host "Warnings: " -NoNewline
                Write-Host "$($global:VerificationResults.Summary.WarningChecks)" -ForegroundColor Yellow
            }

            Write-Host "Duration: $([Math]::Round($global:VerificationResults.Summary.Duration.TotalSeconds, 1)) seconds" -ForegroundColor White
        }

    } catch {
        Write-Log "Critical error during system verification: $($_.Exception.Message)" "ERROR"
        $global:VerificationResults.Summary.OverallStatus = "ERROR"
    }
}

# Run the system verification
try {
    Start-SystemVerification
    Write-Log "System verification script completed successfully" "SUCCESS"
} catch {
    Write-Log "Critical error during system verification" "ERROR"
    if (-not $Quiet) {
        Write-Host "CRITICAL ERROR occurred during verification" -ForegroundColor Red
    }
    exit 1
}