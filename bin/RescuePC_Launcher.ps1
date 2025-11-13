# RescuePC Repairs - GUI Launcher
# Version: 2.0 - Working Version with All Features

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'


Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Path validation and safety functions
$InvalidFileChars = [System.IO.Path]::GetInvalidFileNameChars()
$InvalidPathChars = [System.IO.Path]::GetInvalidPathChars()

function Assert-ValidPathSegment {
    param([Parameter(Mandatory)][string]$Segment, [string]$Label='segment')

    if ([string]::IsNullOrWhiteSpace($Segment)) {
        throw "Path $Label is null/empty."
    }

    foreach ($c in $InvalidFileChars) {
        if ($Segment.Contains([string]$c)) {
            $hex = ('0x{0:X2}' -f [int][char]$c)
            throw "Illegal character $hex '$c' found in $Label segment: '$Segment'"
        }
    }
}

function Assert-ValidPath {
    param([Parameter(Mandatory)][string]$Path, [string]$Label='path')

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Path $Label is null/empty."
    }

    foreach ($c in $InvalidPathChars) {
        if ($Path.Contains([string]$c)) {
            $hex = ('0x{0:X2}' -f [int][char]$c)
            throw "Illegal character $hex '$c' found in $Label: '$Path'"
        }
    }

    # Allow drive colon only after a single letter (e.g., C:)
    if ($Path -match '^(?![A-Za-z]:\\).*:' -and $Path -notmatch '^[A-Za-z]:') {
        throw "Colon appears in the middle of $Label: '$Path'"
    }
}

function Join-PathSafe {
    param(
        [Parameter(Mandatory)][string]$Parent,
        [Parameter(Mandatory)][string]$Child,
        [string]$Label='child'
    )

    Assert-ValidPath $Parent 'parent'
    Assert-ValidPathSegment $Child $Label

    Join-Path -Path $Parent -ChildPath $Child
}

function Try-IO {
    param([scriptblock]$Do, [string]$About="")

    try { & $Do }
    catch {
        # Show the *exact* failing line and message
        $msg = "IO error ($About): " + $_.Exception.Message + "`n" +
               ($_.InvocationInfo.PositionMessage)
        [System.Windows.Forms.MessageBox]::Show($msg, 'RescuePC Repairs Error',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        throw
    }
}

# Error display function
function Show-Err($msg) {
    [System.Windows.Forms.MessageBox]::Show($msg, 'RescuePC Repairs Error',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
}

# Global variables
$global:RepairHistory = @()
$global:RepairInProgress = $false
$global:LicenseValidated = $false
$global:CustomerInfo = $null

# Automated licensing via Next.js API (FREE cloud solution)
# This replaces SharePoint with a serverless API that processes Stripe webhooks

# Get the directory where this script/EXE is running from
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $scriptDir) {
    $scriptDir = Split-Path -Parent $PSScriptRoot
}
if (-not $scriptDir) {
    $scriptDir = Get-Location
}


# Enhanced logging function
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"

    $logDir = Join-Path $scriptDir "logs"
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }

    $logPath = Join-Path $logDir "launcher_log_$(Get-Date -Format 'yyyyMMdd').log"

    try {
        Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue
    } catch {
        # Silent fail if log write fails
    }
}

# Check if running as administrator
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# API-based licensing (FREE cloud solution)
# All licensing functions use the Next.js API endpoints

function Test-InternetConnection {
    try {
        $request = [System.Net.WebRequest]::Create("https://rescuepcrepairs.com/api/health")
        $request.Timeout = 5000
        $response = $request.GetResponse()
        $response.Close()
        return $true
    } catch {
        return $false
    }
}

function Validate-LicenseAPI {
    param(
        [Parameter(Mandatory=$true)][string]$LicenseKey,
        [Parameter(Mandatory=$true)][string]$CustomerEmail
    )

    try {
        $body = @{
            licenseKey = $LicenseKey
            machineId = $env:COMPUTERNAME
        } | ConvertTo-Json

        $response = Invoke-RestMethod -Uri "https://rescuepcrepairs.com/api/activate" -Method POST -Body $body -ContentType "application/json" -TimeoutSec 10

        if ($response.token) {
            return [pscustomobject]@{
                Valid = $true
                Product = $response.plan
                Tier = $response.plan
                CustomerEmail = $response.email
                Token = $response.token
                ExpiresAt = $response.expiresAt
            }
        } else {
            return [pscustomobject]@{
                Valid = $false
                Product = $null
                Tier = $null
                CustomerEmail = $null
                Token = $null
                ExpiresAt = $null
            }
        }
    } catch {
        Write-Log "License validation API error: $($_.Exception.Message)" -Level "ERROR"
        return [pscustomobject]@{
            Valid = $false
            Product = $null
            Tier = $null
            CustomerEmail = $null
            Token = $null
            ExpiresAt = $null
        }
    }
}

function Show-LicensePrompt {

    $licenseForm = New-Object System.Windows.Forms.Form
    $licenseForm.Text = "RescuePC License Validation"
    $licenseForm.Size = New-Object System.Drawing.Size(450, 280)
    $licenseForm.StartPosition = "CenterScreen"
    $licenseForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $licenseForm.MaximizeBox = $false
    $licenseForm.MinimizeBox = $false

    # Header label
    $headerLabel = New-Object System.Windows.Forms.Label
    $headerLabel.Text = "Enter your RescuePC License Key"
    $headerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $headerLabel.Size = New-Object System.Drawing.Size(400, 30)
    $headerLabel.Location = New-Object System.Drawing.Point(20, 20)
    $licenseForm.Controls.Add($headerLabel)

    # Description label
    $descLabel = New-Object System.Windows.Forms.Label
    $descLabel.Text = "Please enter your license key to access RescuePC Repairs Toolkit."
    $descLabel.Size = New-Object System.Drawing.Size(400, 40)
    $descLabel.Location = New-Object System.Drawing.Point(20, 60)
    $licenseForm.Controls.Add($descLabel)

    # License key textbox
    $licenseTextBox = New-Object System.Windows.Forms.TextBox
    $licenseTextBox.Size = New-Object System.Drawing.Size(350, 25)
    $licenseTextBox.Location = New-Object System.Drawing.Point(45, 110)
    $licenseForm.Controls.Add($licenseTextBox)

    # Email textbox
    $emailLabel = New-Object System.Windows.Forms.Label
    $emailLabel.Text = "Email Address:"
    $emailLabel.Size = New-Object System.Drawing.Size(100, 20)
    $emailLabel.Location = New-Object System.Drawing.Point(45, 145)
    $licenseForm.Controls.Add($emailLabel)

    $emailTextBox = New-Object System.Windows.Forms.TextBox
    $emailTextBox.Size = New-Object System.Drawing.Size(350, 25)
    $emailTextBox.Location = New-Object System.Drawing.Point(45, 165)
    $licenseForm.Controls.Add($emailTextBox)

    # OK button
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "Validate License"
    $okButton.Size = New-Object System.Drawing.Size(100, 30)
    $okButton.Location = New-Object System.Drawing.Point(150, 210)
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $licenseForm.AcceptButton = $okButton
    $licenseForm.Controls.Add($okButton)

    # Cancel button
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Size = New-Object System.Drawing.Size(80, 30)
    $cancelButton.Location = New-Object System.Drawing.Point(260, 210)
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $licenseForm.CancelButton = $cancelButton
    $licenseForm.Controls.Add($cancelButton)

    $result = $licenseForm.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $licenseKey = $licenseTextBox.Text.Trim()
        $customerEmail = $emailTextBox.Text.Trim()

        if ([string]::IsNullOrEmpty($licenseKey)) {
            [System.Windows.Forms.MessageBox]::Show("Please enter a license key.", "Invalid License", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return $false
        }

        Write-Log "Validating license key..." -Level "INFO"

        $validationResult = Validate-LicenseAPI -LicenseKey $licenseKey -CustomerEmail $customerEmail

        if ($validationResult.Valid) {
            $global:LicenseValidated = $true
            $global:CustomerInfo = @{
                CustomerName = "Customer"
                Email = $validationResult.CustomerEmail
                PackageName = $validationResult.Product
                Tier = $validationResult.Tier
                IssuedAt = $validationResult.IssuedAt
            }

            Write-Log "License validated for email: $($validationResult.CustomerEmail) - Product: $($validationResult.Product)" -Level "SUCCESS"

            [System.Windows.Forms.MessageBox]::Show(
                "License validated successfully!`n`nEmail: $($validationResult.CustomerEmail)`nProduct: $($validationResult.Product)`nTier: $($validationResult.Tier)",
                "License Validated",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information)

            return $true
        } else {
            [System.Windows.Forms.MessageBox]::Show("Invalid license key or email combination. Please check your license details and try again.", "License Validation Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            Write-Log "License validation failed for key: $licenseKey, email: $customerEmail" -Level "WARNING"
            return $false
        }
    }

    return $false
}

# Simple button creation function
function New-SimpleButton {
    param(
        [string]$Text,
        [string]$ActionName
    )
    
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Name = $ActionName
    $button.Size = New-Object System.Drawing.Size(200, 40)
    $button.Margin = New-Object System.Windows.Forms.Padding(5)
    $button.BackColor = [System.Drawing.Color]::White
    $button.ForeColor = [System.Drawing.Color]::Black
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    
    $button.Add_Click({
        Invoke-ButtonAction -action $this.Name
    })
    
    return $button
}

# Function to handle button actions
function Invoke-ButtonAction {
    param ([string]$action)
    
    if ($global:RepairInProgress) {
        [System.Windows.Forms.MessageBox]::Show("A repair is currently in progress. Please wait for it to complete.", 
            "Operation in Progress", 
            [System.Windows.Forms.MessageBoxButtons]::OK, 
            [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }
    
    $global:RepairInProgress = $true
    Write-Log "Button clicked: $action"
    
    try {
        switch ($action) {  
            "SysHealthCheck" {
                $scriptPath = "$scriptDir\scripts\security\SysHealthCheck.ps1"
                if (Test-Path $scriptPath) {
                    & $scriptPath
                    $result = $LASTEXITCODE
                    if ($result -eq 0) {
                        Write-Log "System Health Check completed successfully" -Level "SUCCESS"
                        [System.Windows.Forms.MessageBox]::Show("System Health Check completed successfully!", "Health Check Complete", 0, 64)
                    } else {
                        [System.Windows.Forms.MessageBox]::Show("System Health Check failed (exit $result).", "Health Check Failed", 0, 16)
                    }
                }
            }
            "CleanPC" {
                $scriptPath = "$scriptDir\scripts\repair\boost_performance.ps1"
                if (Test-Path $scriptPath) {
                    & $scriptPath
                    $result = $LASTEXITCODE
                    if ($result -eq 0) {
                        Write-Log "System cleaning completed successfully" -Level "SUCCESS"
                        [System.Windows.Forms.MessageBox]::Show("System cleaning completed successfully!", "Cleanup Complete", 0, 64)
                    } else {
                        [System.Windows.Forms.MessageBox]::Show("System cleaning failed (exit $result).", "Cleanup Failed", 0, 16)
                    }
                }
            }
            "FixNetwork" {
                $scriptPath = "$scriptDir\scripts\repair\fix_network.ps1"
                if (Test-Path $scriptPath) {
                    & $scriptPath
                    $result = $LASTEXITCODE
                    if ($result -eq 0) {
                        Write-Log "Network fix completed successfully" -Level "SUCCESS"
                        [System.Windows.Forms.MessageBox]::Show("Network repair completed successfully!", "Network Repair Complete", 0, 64)
                    } else {
                        [System.Windows.Forms.MessageBox]::Show("Network repair failed (exit $result).", "Network Repair Failed", 0, 16)
                    }
                }
            }
            "RepairAudio" {
                $scriptPath = "$scriptDir\scripts\repair\repair_audio.ps1"
                if (Test-Path $scriptPath) {
                    & $scriptPath
                    $result = $LASTEXITCODE
                    if ($result -eq 0) {
                        Write-Log "Audio repair completed successfully" -Level "SUCCESS"
                        [System.Windows.Forms.MessageBox]::Show("Audio repair completed successfully!", "Audio Repair Complete", 0, 64)
                    } else {
                        [System.Windows.Forms.MessageBox]::Show("Audio repair failed (exit $result).", "Audio Repair Failed", 0, 16)
                    }
                }
            }
            "RepairServices" {
                $scriptPath = "$scriptDir\scripts\repair\repair_services.ps1"
                if (Test-Path $scriptPath) {
                    & $scriptPath
                    $result = $?
                    if ($result) {
                        Write-Log "Services repair completed successfully" -Level "SUCCESS"
                        [System.Windows.Forms.MessageBox]::Show("Windows Services repair completed successfully!", 
                            "Services Repair Complete", 
                            [System.Windows.Forms.MessageBoxButtons]::OK, 
                            [System.Windows.Forms.MessageBoxIcon]::Information)
                    }
                }
            }
            "RebuildWindowsServices" {
                $scriptPath = "$scriptDir\scripts\repair\rebuild_windows_services.ps1"
                if (Test-Path $scriptPath) {
                    & $scriptPath
                    $result = $?
                    if ($result) {
                        Write-Log "Windows Services rebuild completed successfully" -Level "SUCCESS"
                        [System.Windows.Forms.MessageBox]::Show("Windows Services rebuild completed successfully!", 
                            "Services Rebuild Complete", 
                            [System.Windows.Forms.MessageBoxButtons]::OK, 
                            [System.Windows.Forms.MessageBoxIcon]::Information)
                    }
                }
            }
            "FixDisk" {
                $scriptPath = "$scriptDir\scripts\repair\disk_partition_fix.ps1"
                if (Test-Path $scriptPath) {
                    & $scriptPath
                    $result = $?
                    if ($result) {
                        Write-Log "Disk fix completed successfully" -Level "SUCCESS"
                        [System.Windows.Forms.MessageBox]::Show("Disk repair completed successfully!", 
                            "Disk Repair Complete", 
                            [System.Windows.Forms.MessageBoxButtons]::OK, 
                            [System.Windows.Forms.MessageBoxIcon]::Information)
                    }
                }
            }
            "InstallGameDriver" {
                $scriptPath = "$scriptDir\scripts\drivers\install_game_driver.ps1"
                if (Test-Path $scriptPath) {
                    & $scriptPath
                    $result = $?
                    if ($result) {
                        Write-Log "Game driver installation completed successfully" -Level "SUCCESS"
                        [System.Windows.Forms.MessageBox]::Show("Game driver installation completed successfully!", 
                            "Game Driver Installation Complete", 
                            [System.Windows.Forms.MessageBoxButtons]::OK, 
                            [System.Windows.Forms.MessageBoxIcon]::Information)
                    }
                }
            }
            "StartupRepair" {
                $scriptPath = "$scriptDir\scripts\repair\fix_startup_issues.ps1"
                if (Test-Path $scriptPath) {
                    & $scriptPath
                    $result = $?
                    if ($result) {
                        Write-Log "Startup repair completed successfully" -Level "SUCCESS"
                        [System.Windows.Forms.MessageBox]::Show("Startup repair completed successfully!", 
                            "Startup Repair Complete", 
                            [System.Windows.Forms.MessageBoxButtons]::OK, 
                            [System.Windows.Forms.MessageBoxIcon]::Information)
                    }
                }
            }
            "BackupTool" {
                $scriptPath = "$scriptDir\scripts\repair\backup_user_data.ps1"
                if (Test-Path $scriptPath) {
                    & $scriptPath
                    $result = $?
                    if ($result) {
                        Write-Log "Backup completed successfully" -Level "SUCCESS"
                        [System.Windows.Forms.MessageBox]::Show("Backup completed successfully!", 
                            "Backup Complete", 
                            [System.Windows.Forms.MessageBoxButtons]::OK, 
                            [System.Windows.Forms.MessageBoxIcon]::Information)
                    }
                }
            }
            "OptimizeSystem" {
                $scriptPath = "$scriptDir\scripts\repair\optimize_system.ps1"
                if (Test-Path $scriptPath) {
                    & $scriptPath
                    $result = $?
                    if ($result) {
                        Write-Log "System optimization completed successfully" -Level "SUCCESS"
                        [System.Windows.Forms.MessageBox]::Show("System optimization completed successfully!", 
                            "System Optimization Complete", 
                            [System.Windows.Forms.MessageBoxButtons]::OK, 
                            [System.Windows.Forms.MessageBoxIcon]::Information)
                    }
                }
            }
            "VerifySystem" {
                $scriptPath = "$scriptDir\scripts\security\verify_system.ps1"
                if (Test-Path $scriptPath) {
                    & $scriptPath
                    $result = $?
                    if ($result) {
                        Write-Log "System verification completed successfully" -Level "SUCCESS"
                        [System.Windows.Forms.MessageBox]::Show("System verification completed successfully! Check the reports folder for detailed results.", "System Verification Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                    }
                }
            }
            "MalwareScan" {
                $scriptPath = "$scriptDir\scripts\security\malware_scan_removal.ps1"
                if (Test-Path $scriptPath) {
                    & $scriptPath
                    $result = $?
                    if ($result) {
                        Write-Log "Malware scan and removal completed successfully" -Level "SUCCESS"
                        [System.Windows.Forms.MessageBox]::Show("Malware scan and removal completed successfully!",
                            "Malware Scan Complete",
                            [System.Windows.Forms.MessageBoxButtons]::OK,
                            [System.Windows.Forms.MessageBoxIcon]::Information)
                    }
                }
            }
            "AISystemDiagnostics" {
                $scriptPath = "$scriptDir\scripts\security\ai_system_diagnostics.ps1"
                if (Test-Path $scriptPath) {
                    & $scriptPath
                    $result = $LASTEXITCODE
                    if ($result -eq 0) {
                        Write-Log "AI diagnostics completed successfully" -Level "SUCCESS"
                        [System.Windows.Forms.MessageBox]::Show("Diagnostics completed successfully.`nLog saved to diagnostics folder.","Diagnostics",0,64)
                    } elseif ($result -eq 10) {
                        [System.Windows.Forms.MessageBox]::Show("Diagnostics completed with warnings. Check the log.","Diagnostics",0,48)
                    } elseif ($result -eq 124) {
                        [System.Windows.Forms.MessageBox]::Show("Diagnostics timed out.","Diagnostics",0,48)
                    } else {
                        [System.Windows.Forms.MessageBox]::Show("Diagnostics failed (exit $result). See logs.","Diagnostics",0,16)
                    }
                }
            }
            "SDIO" {
                $scriptPath = "$scriptDir\scripts\drivers\direct_sdio_download.ps1"
                if (Test-Path $scriptPath) {
                    & $scriptPath
                    $result = $LASTEXITCODE
                    if ($result -eq 0) {
                        Write-Log "SDIO download completed successfully" -Level "SUCCESS"
                        [System.Windows.Forms.MessageBox]::Show("SDIO download completed successfully!", "SDIO Complete", 0, 64)
                    } else {
                        [System.Windows.Forms.MessageBox]::Show("SDIO download failed (exit $result).", "SDIO Failed", 0, 16)
                    }
                }
            }
            "ViewLogs" {
                $logsPath = "$scriptDir\logs"
                if (Test-Path $logsPath) {
                    Start-Process "explorer.exe" -ArgumentList $logsPath
                    Write-Log "Opened logs directory" -Level "INFO"
                }
            }
            "CheckComponents" {
                $scriptPath = "$scriptDir\scripts\security\verify_system.ps1"
                if (Test-Path $scriptPath) {
                    & $scriptPath
                    $result = $?
                    if ($result) {
                        Write-Log "Component check completed successfully" -Level "SUCCESS"
                        [System.Windows.Forms.MessageBox]::Show("Component check completed successfully!", 
                            "Component Check Complete", 
                            [System.Windows.Forms.MessageBoxButtons]::OK, 
                            [System.Windows.Forms.MessageBoxIcon]::Information)
                    }
                }
            }
            "Help" {
                [System.Windows.Forms.MessageBox]::Show(
                    "RescuePC Repairs Toolkit v2.0`n`nThis toolkit provides comprehensive tools to repair and optimize Windows systems.`n`nFeatures include:`n- System cleaning and optimization`n- Network and audio repair`n- Windows Update fixes`n- Driver management`n- Security scanning`n- Performance boosting`n- And much more!`n`nFor detailed documentation, check the documentation folder.",
                    "About RescuePC Repairs",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information)
            }
            default {
                [System.Windows.Forms.MessageBox]::Show("This feature is not yet implemented.", "Not Implemented", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            }
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Log "Error executing action $action - $errorMessage" -Level "ERROR"
        [System.Windows.Forms.MessageBox]::Show("Error executing action - $errorMessage", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    finally {
        $global:RepairInProgress = $false
    }
}

# Main function to create and show GUI
function Show-RescuePCRepairGUI {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "RescuePC Repairs Toolkit v2.0"
    $form.Size = New-Object System.Drawing.Size(1200, 800)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    
    # Header
    $headerLabel = New-Object System.Windows.Forms.Label
    $headerLabel.Text = "RescuePC Repairs Toolkit"
    $headerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
    $headerLabel.ForeColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
    $headerLabel.Size = New-Object System.Drawing.Size(400, 30)
    $headerLabel.Location = New-Object System.Drawing.Point(20, 20)
    $form.Controls.Add($headerLabel)
    
    # Status indicator
    $isAdmin = Test-Administrator
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = if ($isAdmin) { "Running as Administrator" } else { "Limited Access Mode" }
    $statusLabel.ForeColor = if ($isAdmin) { [System.Drawing.Color]::Green } else { [System.Drawing.Color]::Orange }
    $statusLabel.Size = New-Object System.Drawing.Size(200, 20)
    $statusLabel.Location = New-Object System.Drawing.Point(20, 60)
    $form.Controls.Add($statusLabel)
    
    # FlowLayoutPanel for buttons
    $flowPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $flowPanel.Location = New-Object System.Drawing.Point(20, 100)
    $flowPanel.Size = New-Object System.Drawing.Size(1160, 650)
    $flowPanel.AutoScroll = $true
    $form.Controls.Add($flowPanel)
    
    # Add all buttons - minimal, focused toolkit
    $flowPanel.Controls.Add((New-SimpleButton -Text "System Health Check" -ActionName "SysHealthCheck"))
    $flowPanel.Controls.Add((New-SimpleButton -Text "Clean My PC" -ActionName "CleanPC"))
    $flowPanel.Controls.Add((New-SimpleButton -Text "Fix Network" -ActionName "FixNetwork"))
    $flowPanel.Controls.Add((New-SimpleButton -Text "Repair Audio" -ActionName "RepairAudio"))
    $flowPanel.Controls.Add((New-SimpleButton -Text "Repair Services" -ActionName "RepairServices"))
    $flowPanel.Controls.Add((New-SimpleButton -Text "Rebuild Windows Services" -ActionName "RebuildWindowsServices"))
    $flowPanel.Controls.Add((New-SimpleButton -Text "Fix Disk" -ActionName "FixDisk"))
    $flowPanel.Controls.Add((New-SimpleButton -Text "Startup Repair" -ActionName "StartupRepair"))
    $flowPanel.Controls.Add((New-SimpleButton -Text "Driver Packs (SDIO)" -ActionName "SDIO"))
    $flowPanel.Controls.Add((New-SimpleButton -Text "Install Game Driver" -ActionName "InstallGameDriver"))
    $flowPanel.Controls.Add((New-SimpleButton -Text "Malware Scan & Removal" -ActionName "MalwareScan"))
    $flowPanel.Controls.Add((New-SimpleButton -Text "Verify System" -ActionName "VerifySystem"))
    $flowPanel.Controls.Add((New-SimpleButton -Text "Optimize System" -ActionName "OptimizeSystem"))
    $flowPanel.Controls.Add((New-SimpleButton -Text "Backup Tool" -ActionName "BackupTool"))
    $flowPanel.Controls.Add((New-SimpleButton -Text "AI System Diagnostics" -ActionName "AISystemDiagnostics"))
    $flowPanel.Controls.Add((New-SimpleButton -Text "View Logs" -ActionName "ViewLogs"))
    $flowPanel.Controls.Add((New-SimpleButton -Text "Check Components" -ActionName "CheckComponents"))
    $flowPanel.Controls.Add((New-SimpleButton -Text "Help" -ActionName "Help"))
    
    # Log the application start
    Write-Log "RescuePC Repairs Launcher started. Running as administrator: $isAdmin" -Level $(if ($isAdmin) { "SUCCESS" } else { "WARNING" })
    
    # Show the form
    $form.ShowDialog()
}

# API Licensing configuration (FREE cloud solution)
# Uses Next.js serverless functions with Stripe webhooks
# Automatically processes payments and generates licenses

# Main application execution with proper error handling
try {
    # Validate base directory
    Assert-ValidPath $scriptDir 'scriptDir'

    Try-IO { Test-Path $scriptDir } 'validating script directory' | Out-Null
    if (-not $?) {
        throw "Script directory does not exist: $scriptDir"
    }

    # Create logs directory safely
    $logDir = Join-PathSafe $scriptDir "logs" -Label 'logs directory'
    Try-IO {
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
    } 'creating logs directory'

    # Test API licensing connection
    Write-Log "Testing licensing server connection..." -Level "INFO"
    if (-not (Test-InternetConnection)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Unable to connect to the licensing server. Please check your internet connection.`n`nThe application will continue with limited functionality.",
            "Licensing Connection Warning",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning)

        Write-Log "Licensing server connection failed - continuing with limited functionality" -Level "WARNING"
    } else {
        Write-Log "Licensing server connection successful" -Level "SUCCESS"

        # Show license prompt
        Write-Log "Prompting for license validation..." -Level "INFO"
        $licenseValid = Show-LicensePrompt

        if (-not $licenseValid) {
            Write-Log "License validation failed or was cancelled" -Level "WARNING"
            [System.Windows.Forms.MessageBox]::Show("License validation is required to use RescuePC Repairs Toolkit.", "License Required", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            exit 0
        }
    }

    # TEMPORARILY DISABLE ADMIN CHECK FOR TESTING
    $isAdmin = Test-Administrator
    if (-not $isAdmin) {
        [System.Windows.Forms.MessageBox]::Show(
            "WARNING: Running without administrator privileges for testing.`n`nSome repair functions may not work properly.",
            "Testing Mode",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
    }

    # Launch the main GUI
    Show-RescuePCRepairGUI
}
catch {
    $errorMessage = $_.Exception.Message
    Write-Host "Error: $errorMessage" -ForegroundColor Red
    Show-Err "An error occurred: $errorMessage"
    exit 1
}
