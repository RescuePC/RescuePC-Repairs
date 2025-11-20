[CmdletBinding()]
param()

function Get-SecurityStatus {
    $status = [ordered]@{
        Timestamp          = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ComputerName       = $env:COMPUTERNAME
        WindowsVersion     = [System.Environment]::OSVersion.VersionString
        LastSystemStartTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    }

    try {
        $session        = New-Object -ComObject "Microsoft.Update.Session"
        $searcher       = $session.CreateUpdateSearcher()
        $pending        = $searcher.Search("IsInstalled=0").Updates
        $status.PendingUpdates = $pending.Count
    } catch {
        $status.PendingUpdates = "Could not check"
    }

    try {
        $def = Get-MpComputerStatus
        $status.Defender = @{
            AntivirusEnabled    = $def.AntivirusEnabled
            RealTimeProtection  = $def.RealTimeProtectionEnabled
            AntispywareEnabled  = $def.AntispywareEnabled
            LastFullScan        = $def.LastFullScanTime
        }
    } catch {
        $status.Defender = "Could not check"
    }

    try {
        $status.Firewall = @{
            DomainEnabled  = (Get-NetFirewallProfile -Profile Domain).Enabled
            PrivateEnabled = (Get-NetFirewallProfile -Profile Private).Enabled
            PublicEnabled  = (Get-NetFirewallProfile -Profile Public).Enabled
        }
    } catch {
        $status.Firewall = "Could not check"
    }

    try {
        $uac = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        $status.UAC = @{
            Enabled = ($uac.EnableLUA -ne 0)
            Level   = $uac.ConsentPromptBehaviorAdmin
        }
    } catch {
        $status.UAC = "Could not check"
    }

    $status
}

try {
    $securityStatus = Get-SecurityStatus
    $outDir = "C:\Users\Tyler\Desktop\RescuePC Repairs\scripts\logs\security"
    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    $outputPath = Join-Path $outDir ("security_status_{0}.json" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
    $securityStatus | ConvertTo-Json -Depth 6 | Out-File -FilePath $outputPath -Encoding utf8

    Write-Host "Security status report saved to: $outputPath" -ForegroundColor Green
    exit 0
} catch {
    Write-Error "Error generating security status report: $_"
    exit 1
}
