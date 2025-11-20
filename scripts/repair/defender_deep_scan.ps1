[CmdletBinding()]
param()

Write-Host "=== RescuePC - Defender Deep Scan ===" -ForegroundColor Cyan

try {
    # Check if Windows Defender is available
    $null = Get-MpPreference -ErrorAction Stop
} catch {
    Write-Error "Windows Defender is not available on this system."
    exit 1
}

Write-Host "Starting Windows Defender full system scan..."
Start-MpScan -ScanType FullScan

Write-Host "Scan started. You can monitor progress in Windows Security."
exit 0
