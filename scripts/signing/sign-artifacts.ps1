param(
    [string]$CertThumbprint
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

Write-Host '=== RescuePC Signing Script ===' -ForegroundColor Cyan
Write-Host "Repo root: $repoRoot"

$signtool = 'C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe'
if (-not (Test-Path $signtool)) {
    throw "signtool.exe not found at $signtool"
}

$exePath = Join-Path $repoRoot 'RescuePC Repairs.exe'
if (-not (Test-Path $exePath)) {
    Write-Host "EXE not found at $exePath - skipping signing" -ForegroundColor Yellow
    exit 0
}

Write-Host "Signing EXE: $exePath" -ForegroundColor Yellow
& $signtool sign /sha1 $CertThumbprint /tr 'http://timestamp.digicert.com' /td sha256 /fd sha256 "$exePath"

$cert = Get-ChildItem "Cert:\CurrentUser\My\$CertThumbprint" -ErrorAction SilentlyContinue
if ($cert) {
    $psTargets = @(
        'bin\RescuePC_Launcher.ps1',
        'scripts\full-setup-and-test.ps1',
        'scripts\security-audit.ps1',
        'scripts\migrate-database.ps1'
    )

    foreach ($rel in $psTargets) {
        $path = Join-Path $repoRoot $rel
        if (Test-Path $path) {
            Write-Host "Signing PowerShell script: $path"
            Set-AuthenticodeSignature -FilePath $path -Certificate $cert | Out-Null
        }
    }
}

Write-Host 'Signing complete.' -ForegroundColor Green
