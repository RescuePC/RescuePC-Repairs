#Requires -Version 5.1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

#region Paths / logging --------------------------------------------------------

function Get-RescuePCBaseDirectory {
    try {
        if ($PSScriptRoot -and (Test-Path $PSScriptRoot)) {
            # When running as .ps1 from bin folder
            return (Split-Path -Parent $PSScriptRoot)
        }
    } catch { }

    try {
        if ($MyInvocation.MyCommand.Path -and (Test-Path $MyInvocation.MyCommand.Path)) {
            # When compiled to EXE or running as .ps1
            $scriptPath = $MyInvocation.MyCommand.Path
            # If we're in the bin folder, go up one level
            if ($scriptPath -match '\\bin\\') {
                return (Split-Path -Parent (Split-Path -Parent $scriptPath))
            } else {
                return (Split-Path -Parent $scriptPath)
            }
        }
    } catch { }

    # Fallback – assume we're in the project root
    return (Get-Location).Path
}

$BaseDir  = Get-RescuePCBaseDirectory
$ScriptDir = Join-Path $BaseDir 'scripts'
$LogDir   = Join-Path $BaseDir 'bin\logs'

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

function Write-LauncherLog {
    param(
        [string]$Message
    )
    try {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $line = "$timestamp [INFO] $Message"
        $date = Get-Date -Format 'yyyyMMdd'
        $logFile = Join-Path $LogDir "launcher_log_$date.log"
        Add-Content -Path $logFile -Value $line -Encoding UTF8
    } catch {
        # Never let logging crash the launcher
    }
}

#endregion Paths / logging -----------------------------------------------------

#region License validation -----------------------------------------------------

function Get-RescuePCLicense {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LicenseKey,
        [string]$MachineId = (Get-ComputerInfo -Property CsProductUUID).CsProductUUID
    )

    $body = @{
        licenseKey = $LicenseKey
        machineId  = $MachineId
    } | ConvertTo-Json

    $uri = "https://rescuepcrepairs.com/api/verify-license"

    try {
        $response = Invoke-RestMethod -Uri $uri `
                                  -Method POST `
                                  -Body $body `
                                  -ContentType "application/json" `
                                  -ErrorAction Stop

        if (-not $response.ok) {
            throw "License validation failed: $($response.error)"
        }

        return $response
    } catch {
        $errorMsg = $_.Exception.Message
        Write-LauncherLog "License validation error: $errorMsg"
        
        return [pscustomobject]@{
            ok        = $false
            error     = "SERVER_OR_NETWORK_ERROR"
            message   = "Unable to validate license: $errorMsg"
        }
    }
}

function Show-RescuePCLicenseSummary {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$License
    )

    Write-Host "=== RescuePC License Status ===" -ForegroundColor Cyan
    Write-Host "Plan: $($License.planLabel) [$($License.plan)]"
    Write-Host "Description: $($License.planDescription)"

    if ($License.lifetime) {
        Write-Host "Type: Lifetime license (product lifetime)" -ForegroundColor Green
    } else {
        Write-Host "Type: Annual license"
        if ($License.expiresAt) {
            Write-Host "Expires: $($License.expiresAt)"
        }
    }

    Write-Host ""
    Write-Host "Usage rights:" -ForegroundColor Yellow
    Write-Host ("  Personal use:           " + ($(if ($License.rights.personalUse)  { "Allowed" } else { "Not allowed" })))
    Write-Host ("  Commercial / repair:    " + ($(if ($License.rights.commercialUse){ "Allowed" } else { "Not allowed" })))
    Write-Host ("  Business / fleets:      " + ($(if ($License.rights.businessUse)   { "Allowed" } else { "Not allowed" })))
    Write-Host ("  Remote assistance:      " + ($(if ($License.rights.remoteAssistIncluded) { "Included (Enterprise)" } else { "Not included" })))
    Write-Host ("  Dedicated support:      " + ($(if ($License.rights.dedicatedSupport) { "Included" } else { "Standard" })))
    Write-Host ""
}

function Show-LicenseSummary {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$LicenseInfo
    )
    
    if (-not $LicenseInfo -or -not $LicenseInfo.ok) {
        Write-Host "=== License Status: Not Activated ===" -ForegroundColor Red
        Write-Host "Running in limited mode with basic functionality."
        return
    }
    
    $license = $LicenseInfo.license
    $planLabel = if ($LicenseInfo.planLabel) { $LicenseInfo.planLabel } elseif ($license.planName) { $license.planName } else { "Unknown Plan" }
    $expires = if ($license -and $license.expiresAt) { [datetime]::Parse($license.expiresAt).ToString("yyyy-MM-dd") } else { "Never" }
    
    Write-Host "=== $planLabel License ===" -ForegroundColor Green
    Write-Host "Plan: $planLabel"
    Write-Host "Status: Active" -ForegroundColor Green
    
    if ($license.lifetime) {
        Write-Host "Type: Lifetime License" -ForegroundColor Cyan
    } else {
        Write-Host "Expires: $expires"
    }
    
    Write-Host "`n=== Usage Rights ===" -ForegroundColor Yellow
    $rights = if ($LicenseInfo.rights) { $LicenseInfo.rights } else { @{} }
    
    # Display rights with checkmarks or X marks
    $check = [char]0x2713 # Checkmark
    $cross = [char]0x2717 # X mark
    
    Write-Host ("  {0} Personal Use" -f ($check, $cross)[!$rights.personalUse])
    Write-Host ("  {0} Commercial/Repair Use" -f ($check, $cross)[!$rights.commercialUse])
    Write-Host ("  {0} Business/Fleet Use" -f ($check, $cross)[!$rights.businessUse])
    
    if ($rights.remoteAssistIncluded) {
        Write-Host "  $check Remote Assistance Included" -ForegroundColor Cyan
    } else {
        Write-Host "  $cross Remote Assistance (Enterprise only)"
    }
    
    $maxDevices = if ($rights.maxDevices) { $rights.maxDevices } else { 1 }
    Write-Host "  Max Devices: $maxDevices"
    
    # Show machine binding info if available
    if ($license.machineId) {
        $machineId = if ($license.machineId) { 
        if ($license.machineId -is [PSCustomObject] -and $license.machineId.machineId) {
            $license.machineId.machineId 
        } else { 
            $license.machineId 
        }
    }
        
        if ($machineId) {
            $shortId = if ($machineId.Length -gt 12) { $machineId.Substring(0, 12) + "..." } else { $machineId }
            Write-Host "`nMachine ID: $shortId" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
}

#endregion License validation -----------------------------------------------------

#region License prompt / state -------------------------------------------------

$global:LicenseValid   = $false
$global:LicenseSummary = 'Limited Access Mode'
$global:IsOwnerLicense = $false
$global:LicenseInfo    = $null

# DPAPI License Cache Functions
$licenseCacheDir  = Join-Path $env:ProgramData "RescuePC"
$licenseCachePath = Join-Path $licenseCacheDir "license_cache.xml"

function Save-LicenseCache {
    param(
        [string]$Email,
        [string]$LicenseKey,
        [bool]$IsOwner,
        [object]$LicenseData
    )
    
    try {
        if (-not (Test-Path $licenseCacheDir)) {
            New-Item -ItemType Directory -Path $licenseCacheDir -Force | Out-Null
        }

        $cacheObject = [pscustomobject]@{
            Email      = $Email
            LicenseKey = $LicenseKey
            IsOwner    = $IsOwner
            LicenseData = $LicenseData
            CachedAt   = (Get-Date)
        }

        # Protect with DPAPI so only THIS Windows user can decrypt
        $cacheObject | Export-Clixml -Path $licenseCachePath
        Write-LauncherLog "License cache saved for $Email (Owner: $IsOwner)"
    } catch {
        Write-LauncherLog "ERROR saving license cache: $($_.Exception.Message)"
    }
}

function Get-LicenseCache {
    $CachedLicense = $null
    
    if (Test-Path $licenseCachePath) {
        try {
            $CachedLicense = Import-Clixml -Path $licenseCachePath
            Write-LauncherLog "License cache loaded for $($CachedLicense.Email)"
        } catch {
            Write-LauncherLog "ERROR loading license cache: $($_.Exception.Message)"
            $CachedLicense = $null
        }
    }
    
    return $CachedLicense
}

function Test-CachedLicense {
    param([object]$CachedLicense)
    
    if (-not $CachedLicense -or -not $CachedLicense.Email -or -not $CachedLicense.LicenseKey) {
        return $false
    }

    try {
        Write-LauncherLog "Testing cached license for $($CachedLicense.Email)..."
        
        $licenseResult = Invoke-RescuePCLicenseCheck -LicenseKey $CachedLicense.LicenseKey -CustomerEmail $CachedLicense.Email

        if ($licenseResult.valid) {
            Write-LauncherLog "Cached license is still valid"
            return $licenseResult
        } else {
            Write-LauncherLog "Cached license is no longer valid"
            return $false
        }
    } catch {
        Write-LauncherLog "ERROR testing cached license: $($_.Exception.Message)"
        return $false
    }
}

function Show-LicensePrompt {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'RescuePC - Activate License'
    $form.Size = New-Object System.Drawing.Size(500, 350)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    
    # Title
    $labelTitle = New-Object System.Windows.Forms.Label
    $labelTitle.Location = New-Object System.Drawing.Point(20, 20)
    $labelTitle.Size = New-Object System.Drawing.Size(440, 30)
    $labelTitle.Text = 'Enter Your License Information'
    $labelTitle.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($labelTitle)
    
    # Email Label
    $labelEmail = New-Object System.Windows.Forms.Label
    $labelEmail.Location = New-Object System.Drawing.Point(20, 70)
    $labelEmail.Size = New-Object System.Drawing.Size(100, 20)
    $labelEmail.Text = 'Email:'
    $form.Controls.Add($labelEmail)
    
    # Email Input
    $textBoxEmail = New-Object System.Windows.Forms.TextBox
    $textBoxEmail.Location = New-Object System.Drawing.Point(120, 67)
    $textBoxEmail.Size = New-Object System.Drawing.Size(340, 20)
    $form.Controls.Add($textBoxEmail)
    
    # License Key Label
    $labelKey = New-Object System.Windows.Forms.Label
    $labelKey.Location = New-Object System.Drawing.Point(20, 110)
    $labelKey.Size = New-Object System.Drawing.Size(100, 20)
    $labelKey.Text = 'License Key:'
    $form.Controls.Add($labelKey)
    
    # License Key Input
    $textBoxKey = New-Object System.Windows.Forms.TextBox
    $textBoxKey.Location = New-Object System.Drawing.Point(120, 107)
    $textBoxKey.Size = New-Object System.Drawing.Size(340, 20)
    $form.Controls.Add($textBoxKey)
    
    # Status Label
    $labelStatus = New-Object System.Windows.Forms.Label
    $labelStatus.Location = New-Object System.Drawing.Point(20, 150)
    $labelStatus.Size = New-Object System.Drawing.Size(440, 40)
    $labelStatus.Text = 'Enter your email and license key to activate RescuePC.'
    $form.Controls.Add($labelStatus)
    
    # Activate Button
    $buttonActivate = New-Object System.Windows.Forms.Button
    $buttonActivate.Location = New-Object System.Drawing.Point(300, 200)
    $buttonActivate.Size = New-Object System.Drawing.Size(80, 30)
    $buttonActivate.Text = 'Activate'
    $buttonActivate.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $buttonActivate
    $form.Controls.Add($buttonActivate)
    
    # Cancel Button
    $buttonCancel = New-Object System.Windows.Forms.Button
    $buttonCancel.Location = New-Object System.Drawing.Point(380, 200)
    $buttonCancel.Size = New-Object System.Drawing.Size(80, 30)
    $buttonCancel.Text = 'Cancel'
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $buttonCancel
    $form.Controls.Add($buttonCancel)
    
    # Purchase Link
    $linkPurchase = New-Object System.Windows.Forms.LinkLabel
    $linkPurchase.Location = New-Object System.Drawing.Point(20, 200)
    $linkPurchase.Size = New-Object System.Drawing.Size(200, 20)
    $linkPurchase.Text = 'Purchase a License'
    $linkPurchase.Add_Click({ Start-Process 'https://rescuepcrepairs.com/pricing' })
    $form.Controls.Add($linkPurchase)
    
    # Validation function
    $validateInputs = {
        $isValid = $textBoxEmail.Text -match '^[^@\s]+@[^@\s]+\.[^@\s]+$' -and $textBoxKey.Text.Trim().Length -ge 10
        $buttonActivate.Enabled = $isValid
    }
    
    $textBoxEmail.Add_TextChanged($validateInputs)
    $textBoxKey.Add_TextChanged($validateInputs)
    
    $result = $form.ShowDialog()
    
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return @{
            Email = $textBoxEmail.Text.Trim()
            LicenseKey = $textBoxKey.Text.Trim()
        }
    }
    
    return $null
    $result = @{
        Valid   = $false
        Summary = 'Limited Access Mode'
        IsOwner = $false
    }

    $form              = New-Object System.Windows.Forms.Form
    $form.Text         = 'RescuePC License Validation'
    $form.StartPosition = 'CenterScreen'
    $form.Size         = New-Object System.Drawing.Size(420,220)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox  = $false
    $form.MinimizeBox  = $false
    $form.TopMost      = $true

    $lblTitle          = New-Object System.Windows.Forms.Label
    $lblTitle.Text     = 'Enter your RescuePC License Key'
    $lblTitle.AutoSize = $true
    $lblTitle.Font     = New-Object System.Drawing.Font('Segoe UI', 11,[System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(20,15)

    $lblKey            = New-Object System.Windows.Forms.Label
    $lblKey.Text       = 'License Key:'
    $lblKey.AutoSize   = $true
    $lblKey.Location   = New-Object System.Drawing.Point(20,55)

    $txtKey            = New-Object System.Windows.Forms.TextBox
    $txtKey.Width      = 360
    $txtKey.Location   = New-Object System.Drawing.Point(20,72)

    $lblEmail          = New-Object System.Windows.Forms.Label
    $lblEmail.Text     = 'Email Address:'
    $lblEmail.AutoSize   = $true
    $lblEmail.Location   = New-Object System.Drawing.Point(20,102)

    $txtEmail          = New-Object System.Windows.Forms.TextBox
    $txtEmail.Width    = 360
    $txtEmail.Location = New-Object System.Drawing.Point(20,119)

    $btnValidate       = New-Object System.Windows.Forms.Button
    $btnValidate.Text  = 'Validate License'
    $btnValidate.Width = 130
    $btnValidate.Location = New-Object System.Drawing.Point(140,155)

    $btnCancel         = New-Object System.Windows.Forms.Button
    $btnCancel.Text    = 'Cancel'
    $btnCancel.Width   = 80
    $btnCancel.Location = New-Object System.Drawing.Point(280,155)

    $form.Controls.AddRange(@(
        $lblTitle,$lblKey,$txtKey,$lblEmail,$txtEmail,$btnValidate,$btnCancel
    ))

    # Global flags used later by main UI
    $Global:IsLimitedMode  = $true
    $Global:CurrentLicense = $null

    $btnValidate.Add_Click({
        try {
            $licenseKey    = $txtKey.Text
            $customerEmail = $txtEmail.Text

            $result = Invoke-RescuePCLicenseCheck `
                -LicenseKey $licenseKey `
                -CustomerEmail $customerEmail

            if (-not $result.valid) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Unable to validate license online. The toolkit will run in Limited Access Mode.`n`nError: $($result.error)",
                    "Licensing Connection Warning",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )

                $Global:IsLimitedMode  = $true
                $Global:CurrentLicense = $null
            }
            else {
                $Global:IsLimitedMode  = $false
                $Global:CurrentLicense = $result.license

                [System.Windows.Forms.MessageBox]::Show(
                    "License validated successfully.`n`nPlan: $($result.license.planName)",
                    "License Validated",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            }

            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                "The running command stopped due to an unexpected error:`n$($_.Exception.Message)",
                "RescuePC Repairs Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )

            # Fail safe into limited mode
            $Global:IsLimitedMode  = $true
            $Global:CurrentLicense = $null

            $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
            $form.Close()
        }
    })

    $btnCancel.Add_Click({
        $Global:IsLimitedMode  = $true
        $Global:CurrentLicense = $null
        $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.Close()
    })

    # Show the dialog before launching main toolkit UI
    $null = $form.ShowDialog()

    return $result
}

#endregion License prompt / state ----------------------------------------------

#region Script map + starter ---------------------------------------------------

# Map button actions to actual script paths
$ScriptMap = @{
    'SysHealthCheck'     = Join-Path $ScriptDir 'security\SysHealthCheck.ps1'
    'CleanPC'            = Join-Path $ScriptDir 'repair\optimize_system.ps1'
    'FixNetwork'         = Join-Path $ScriptDir 'repair\fix_network.ps1'
    'RepairAudio'        = Join-Path $ScriptDir 'repair\repair_audio.ps1'
    'RepairServices'     = Join-Path $ScriptDir 'repair\repair_services.ps1'
    'RebuildServices'    = Join-Path $ScriptDir 'repair\rebuild_windows_services.ps1'
    'FixDisk'            = Join-Path $ScriptDir 'repair\disk_partition_fix.ps1'
    'StartupRepair'      = Join-Path $ScriptDir 'repair\fix_startup_issues.ps1'
    'DriverPacks'        = Join-Path $ScriptDir 'drivers\direct_sdio_download.ps1'
    'InstallGameDriver'  = Join-Path $ScriptDir 'drivers\install_game_driver.ps1'
    'MalwareScan'        = Join-Path $ScriptDir 'security\malware_scan_removal.ps1'
    'VerifySystem'       = Join-Path $ScriptDir 'security\verify_system.ps1'
    'OptimizeSystem'     = Join-Path $ScriptDir 'repair\boost_performance.ps1'
    'BackupTool'         = Join-Path $ScriptDir 'repair\backup_user_data.ps1'
    'AISystemDiag'       = Join-Path $ScriptDir 'security\ai_system_diagnostics.ps1'
}

# For now, we allow all buttons even in limited mode
$AllowedInLimitedMode = $ScriptMap.Keys

function Start-RepairScript {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Key
    )

    if (-not $ScriptMap.ContainsKey($Key)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Unknown repair action: $Key",
            "RescuePC Repairs Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }

    if (-not (Test-Path $ScriptMap[$Key])) {
        [System.Windows.Forms.MessageBox]::Show(
            "Repair script not found:`n$($ScriptMap[$Key])",
            "RescuePC Repairs Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }

    if (-not $global:LicenseValid -and ($Key -notin $AllowedInLimitedMode)) {
        [System.Windows.Forms.MessageBox]::Show(
            "This function normally requires a valid license. You are currently in Limited Access Mode.",
            "License Required",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    $scriptPath = $ScriptMap[$Key]
    Write-LauncherLog "Button clicked: $Key ($scriptPath)"

    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        $psi.UseShellExecute = $true
        $psi.Verb = "runas"   # Always ask for admin

        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {
        Write-LauncherLog "ERROR launching $($Key): $($Error[0].Exception.Message)"
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to start repair script:`n$($ScriptMap[$Key])`n`n$($Error[0].Exception.Message)",
            "RescuePC Repairs Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

#endregion Script map + starter ------------------------------------------------

#region Main UI ----------------------------------------------------------------

function New-MainForm {
    $form              = New-Object System.Windows.Forms.Form
    $form.Text         = 'RescuePC Repairs Toolkit v2.0'
    $form.StartPosition = 'CenterScreen'
    $form.Size         = New-Object System.Drawing.Size(1050,340)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox  = $false

    $lblTitle          = New-Object System.Windows.Forms.Label
    $lblTitle.Text     = 'RescuePC Repairs Toolkit'
    $lblTitle.Font     = New-Object System.Drawing.Font('Segoe UI', 14,[System.Drawing.FontStyle]::Bold)
    $lblTitle.AutoSize = $true
    $lblTitle.Location = New-Object System.Drawing.Point(20,15)

    $lblMode           = New-Object System.Windows.Forms.Label
    $lblMode.AutoSize  = $true
    $lblMode.Location  = New-Object System.Drawing.Point(22,45)

    if ($global:LicenseValid) {
        $lblMode.Text      = $global:LicenseSummary
        $lblMode.ForeColor = [System.Drawing.Color]::Green
    } else {
        $lblMode.Text      = 'Limited Access Mode'
        $lblMode.ForeColor = [System.Drawing.Color]::Orange
    }

    $form.Controls.Add($lblTitle)
    $form.Controls.Add($lblMode)

    # Helper to add buttons in a grid
    function Add-Button {
        param(
            [string]$Text,
            [int]$Row,
            [int]$Col,
            [string]$Key
        )
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $Text
        $btn.Width  = 190
        $btn.Height = 40

        $startX = 20
        $startY = 80
        $spacingX = 200
        $spacingY = 55

        $btn.Location = New-Object System.Drawing.Point(
            $startX + ($Col * $spacingX),
            $startY + ($Row * $spacingY)
        )

        if ($Key) {
            $btn.Add_Click({ Start-RepairScript $Key })
        }

        $form.Controls.Add($btn)
    }

    # Row 0
    Add-Button -Text 'System Health Check' -Row 0 -Col 0 -Key 'SysHealthCheck'
    Add-Button -Text 'Clean My PC'        -Row 0 -Col 1 -Key 'CleanPC'
    Add-Button -Text 'Fix Network'        -Row 0 -Col 2 -Key 'FixNetwork'
    Add-Button -Text 'Repair Audio'       -Row 0 -Col 3 -Key 'RepairAudio'
    Add-Button -Text 'Repair Services'    -Row 0 -Col 4 -Key 'RepairServices'

    # Row 1
    Add-Button -Text 'Rebuild Windows Services' -Row 1 -Col 0 -Key 'RebuildServices'
    Add-Button -Text 'Fix Disk'                 -Row 1 -Col 1 -Key 'FixDisk'
    Add-Button -Text 'Startup Repair'           -Row 1 -Col 2 -Key 'StartupRepair'
    Add-Button -Text 'Driver Packs (SDIO)'      -Row 1 -Col 3 -Key 'DriverPacks'
    Add-Button -Text 'Install Game Driver'      -Row 1 -Col 4 -Key 'InstallGameDriver'

    # Row 2
    Add-Button -Text 'Malware Scan  Removal' -Row 2 -Col 0 -Key 'MalwareScan'
    Add-Button -Text 'Verify System'         -Row 2 -Col 1 -Key 'VerifySystem'
    Add-Button -Text 'Optimize System'       -Row 2 -Col 2 -Key 'OptimizeSystem'
    Add-Button -Text 'Backup Tool'           -Row 2 -Col 3 -Key 'BackupTool'
    Add-Button -Text 'AI System Diagnostics' -Row 2 -Col 4 -Key 'AISystemDiag'

    # Bottom row utilities
    $btnViewLogs = Add-Button -Text 'View Logs' -Row 3 -Col 0 -Key $null
    $btnCheck    = Add-Button -Text 'Check Components' -Row 3 -Col 1 -Key $null
    $btnHelp     = Add-Button -Text 'Help' -Row 3 -Col 2 -Key $null

    # Wire utility buttons
    ($form.Controls | Where-Object { $_.Text -eq 'View Logs' }).Add_Click({
        Start-Process explorer.exe "$ScriptDir\logs" -ErrorAction SilentlyContinue
    })

    ($form.Controls | Where-Object { $_.Text -eq 'Check Components' }).Add_Click({
        Start-RepairScript 'SysHealthCheck'
    })

    ($form.Controls | Where-Object { $_.Text -eq 'Help' }).Add_Click({
        $helpPath = Join-Path $BaseDir 'docs\INSTALLATION_GUIDE.md'
        if (Test-Path $helpPath) {
            Start-Process $helpPath -ErrorAction SilentlyContinue
        } else {
            [System.Windows.Forms.MessageBox]::Show(
                "Help file not found:`n$helpPath",
                "RescuePC Repairs",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        }
    })

    return $form
}

#endregion Main UI -------------------------------------------------------------

#region Entry point ------------------------------------------------------------

try {
    Write-LauncherLog "RescuePC Repairs Launcher starting. BaseDir = $BaseDir"

    # Show welcome message
    Write-Host "=== RescuePC Repairs Toolkit ===" -ForegroundColor Cyan
    Write-Host "Version 2.0.0 | https://rescuepcrepairs.com"
    Write-Host ""

    # If no valid cached license, show the prompt
    if (-not $CachedLicense) {
        $licenseInfo = Show-LicensePrompt
        if (-not $licenseInfo) {
            Write-Host "License activation cancelled. Running in limited mode." -ForegroundColor Yellow
            $global:LicenseValid = $false
        } else {
            # Validate the new license
            $result = Invoke-RescuePCLicenseCheck -LicenseKey $licenseInfo.LicenseKey -CustomerEmail $licenseInfo.Email
            $global:LicenseValid = $result.ok -or $result.valid
            $global:LicenseInfo = $result
            
            if ($global:LicenseValid) {
                # Save the valid license
                Save-LicenseCache -Email $licenseInfo.Email -LicenseKey $licenseInfo.LicenseKey -IsOwner $false -LicenseData $result.license
                $global:LicenseSummary = if ($result.planLabel) { $result.planLabel } elseif ($result.license.planName) { $result.license.planName } else { "Valid License" }
                $global:IsOwnerLicense = $result.license.isOwner -eq $true
                
                # Show license summary
                Show-LicenseSummary -LicenseInfo $result
            } else {
                Write-Host "Invalid license. Running in limited mode." -ForegroundColor Red
                if ($result.error) {
                    $errorMessage = if ($result.message) { $result.message } else { $result.error }
                    Write-Host "Error: $errorMessage" -ForegroundColor Red
                }
                
                # Show limited mode message
                Write-Host "`n=== Limited Mode ===" -ForegroundColor Yellow
                Write-Host "Some features are disabled in limited mode. Please activate a valid license for full access."
            }
        }
    } else {
        # We have a cached license, show its details
        $result = Test-CachedLicense -CachedLicense $CachedLicense
        if ($result) {
            $global:LicenseValid = $true
            $global:LicenseInfo = $result
            $global:LicenseSummary = if ($result.planLabel) { $result.planLabel } elseif ($result.license.planName) { $result.license.planName } else { "Valid License" }
            $global:IsOwnerLicense = $result.license.isOwner -eq $true
            
            # Show license summary
            Show-LicenseSummary -LicenseInfo $result
        } else {
            # Clear invalid cache
            Remove-Item -Path $licenseCachePath -Force -ErrorAction SilentlyContinue
            $global:LicenseValid = $false
            $global:LicenseInfo = $null
            
            # Show limited mode message
            Write-Host "`n=== Limited Mode ===" -ForegroundColor Yellow
            Write-Host "Some features are disabled in limited mode. Please activate a valid license for full access."
        }
    }

    # Either no cache, not owner, or cached license invalid - show prompt
    $license = Show-LicensePrompt
    $global:LicenseValid   = $license.Valid
    $global:LicenseSummary = $license.Summary
    $global:IsOwnerLicense = $license.IsOwner

    $mainForm = New-MainForm
    [void]$mainForm.ShowDialog()
}
catch {
    Write-LauncherLog "FATAL ERROR: $($_.Exception.Message)"
    [System.Windows.Forms.MessageBox]::Show(
        "The running command stopped due to an unexpected error:`n`n$($_.Exception.Message)",
        "RescuePC Repairs",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

#endregion Entry point ---------------------------------------------------------

# SIG # Begin signature block
# MIIFfAYJKoZIhvcNAQcCoIIFbTCCBWkCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUFpXcxoXq/l6cr/zb4nxXeVfX
# 2YOgggMSMIIDDjCCAfagAwIBAgIQc6VPVBbWr69NGcDq7bD4HzANBgkqhkiG9w0B
# AQUFADAfMR0wGwYDVQQDDBRSZXNjdWVQQyBSZXBhaXJzIERldjAeFw0yNTExMTkx
# ODEzMTBaFw0yNjExMTkxODMzMTBaMB8xHTAbBgNVBAMMFFJlc2N1ZVBDIFJlcGFp
# cnMgRGV2MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAx3KkA2KmYCXZ
# OXnSbN5geGFQXAUzKduHKxebPQBtetRR320SuBVAeMJhYqwY0tCu/dAFzNgWeLv9
# pMT1s9oWx/C8Wy/0VcJqPrgNd9kUYsUEICHOdcahsjWOU+0874848lZr5jI2DTVT
# CyTcdGv1t1U08kjiTtdwstZufL+cuXxruD1IqjQrNJ4n78QoUZBRvTJ5CZSEiGaE
# wArxdEeL5yz/TTNHr6Q2ZPRMSQRV39OQy0J6CcTFvEk3VlI5T4DM3xrUHbOxA1RR
# QCQcI0VRzgj0fuNPv7ynVvtqVFz35X640OpDtlDNS0VS0nq11Chs9c/5a2SPsuVr
# Lo34pa5LhQIDAQABo0YwRDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYB
# BQUHAwMwHQYDVR0OBBYEFCpoqMab+Z6hqfItJfvTSHCgviVRMA0GCSqGSIb3DQEB
# BQUAA4IBAQCMF/95XLfMgVqIJvmaJXBghtzSpxI4xVtp8Mc98bBy7BqdXrYh5+St
# Pzy/fFDS4/29eZ7JVM6W4HVmdKd3Ci53NAhTmS1izKy1p89pmycl/a/WxjkB746r
# EhFrSFWGKSDQ9rRYanCRWwx8bG6CT+Nhh/BWpRd635NjG4gNp2IY77rE2qqSf32T
# Eu+0knLIL1TXs9EK5FWE90srv9ihoV62GPVqj4IpmICaEdTnYk/Xz/pCGK2eEPXS
# DeFH/YohLH3VXzFWHOvHdagl5CUYkQ/TWY65nIG4rVnVYLMv+pSzN6ZodItYuiAS
# IOSbUFHgtnpybqOq/AmaIWzRQyfcT2kEMYIB1DCCAdACAQEwMzAfMR0wGwYDVQQD
# DBRSZXNjdWVQQyBSZXBhaXJzIERldgIQc6VPVBbWr69NGcDq7bD4HzAJBgUrDgMC
# GgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYK
# KwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG
# 9w0BCQQxFgQUzCCOw8kVB4jjrIAyXYC52ZqjEBgwDQYJKoZIhvcNAQEBBQAEggEA
# U+FO6EsUtoF+3OEHCQTkq9JMUuAP1lmiqSs+IdCUYlD4A9NlFWwmEuJYs1obST4e
# Jc24PnaEfU/NTFOSfg7yBoj+HUpSHTRC3Icf/xhRXb7cMLp9FLYjDN3XzcneCzPv
# cArZY2rmndpgAAmEYKmjsybhVn8DLbhPNqX0A/TSFsxeD0yb+BJjL6pGfw+/sjET
# xKWGf1e24bLurC/+GvI0W4i1k876IQrpOjHQV5Q/vZypygGlQJr3yy/LJ+uvpLlr
# Vy/A1pD0RowXqiQBqmbSXXs6eHuuF6+sfQISqwjBGM3VcFhxzN3WpE2H9zDen5Ee
# rq3Uo6JWaUMpgRrSRQTfZw==
# SIG # End signature block
