#requires -Version 5.1

<#
.SYNOPSIS
    Code signing script for RescuePC Repairs EXE
.DESCRIPTION
    Signs the EXE with either self-signed cert (free) or commercial cert
.PARAMETER Method
    Signing method: SelfSigned or Commercial
.PARAMETER ExePath
    Path to the EXE file to sign (defaults to ..\RescuePC Repairs.exe)
.EXAMPLE
    .\sign-exe.ps1 -Method SelfSigned
.EXAMPLE
    .\sign-exe.ps1 -Method Commercial -PfxPath "C:\path\to\cert.pfx"
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("SelfSigned", "Commercial")]
    [string]$Method,

    [Parameter(Mandatory = $false)]
    [string]$ExePath = "..\RescuePC Repairs.exe",

    [Parameter(Mandatory = $false)]
    [string]$PfxPath,

    [Parameter(Mandatory = $false)]
    [string]$PfxPassword
)

# Resolve paths
$exeFullPath = Resolve-Path $ExePath
$signtoolPath = "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe" | Get-ChildItem -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $signtoolPath) {
    Write-Error "signtool.exe not found. Install Windows SDK."
    exit 1
}

Write-Host "Signing EXE: $exeFullPath" -ForegroundColor Cyan
Write-Host "Using signtool: $signtoolPath" -ForegroundColor Gray

if ($Method -eq "SelfSigned") {
    # Create self-signed certificate
    Write-Host "Creating self-signed certificate..." -ForegroundColor Yellow

    $cert = New-SelfSignedCertificate `
        -Type CodeSigningCert `
        -Subject "CN=RescuePC Local Signing" `
        -KeyExportPolicy Exportable `
        -KeyLength 4096 `
        -HashAlgorithm SHA256 `
        -CertStoreLocation "Cert:\CurrentUser\My"

    Write-Host "Certificate created: $($cert.Thumbprint)" -ForegroundColor Green

    # Export PFX for signtool
    $tempPfx = "$env:TEMP\rescuepc_temp.pfx"
    $pwd = ConvertTo-SecureString "TempPassword123!" -AsPlainText -Force
    Export-PfxCertificate -Cert $cert -FilePath $tempPfx -Password $pwd

    # Sign with signtool
    Write-Host "Signing EXE with self-signed certificate..." -ForegroundColor Yellow
    & $signtoolPath sign /fd SHA256 /f $tempPfx /p "TempPassword123!" /tr http://timestamp.digicert.com /td SHA256 $exeFullPath

    if ($LASTEXITCODE -eq 0) {
        Write-Host "EXE signed successfully with self-signed certificate!" -ForegroundColor Green
        Write-Host "Note: Users will see 'Unknown Publisher' warning. For production, use a commercial certificate." -ForegroundColor Yellow
    } else {
        Write-Error "Signing failed with exit code: $LASTEXITCODE"
    }

    # Clean up temp PFX
    Remove-Item $tempPfx -ErrorAction SilentlyContinue

} elseif ($Method -eq "Commercial") {
    # Sign with commercial certificate
    if (-not $PfxPath -or -not (Test-Path $PfxPath)) {
        Write-Error "Commercial signing requires -PfxPath parameter with valid PFX file path"
        exit 1
    }

    if (-not $PfxPassword) {
        $securePwd = Read-Host -AsSecureString "Enter PFX password"
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePwd)
        $PfxPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }

    Write-Host "Signing EXE with commercial certificate..." -ForegroundColor Yellow
    & $signtoolPath sign /fd SHA256 /f $PfxPath /p $PfxPassword /tr http://timestamp.digicert.com /td SHA256 $exeFullPath

    if ($LASTEXITCODE -eq 0) {
        Write-Host "EXE signed successfully with commercial certificate!" -ForegroundColor Green
        Write-Host "No 'Unknown Publisher' warnings for users." -ForegroundColor Green
    } else {
        Write-Error "Signing failed with exit code: $LASTEXITCODE"
    }
}

# Verify signature
Write-Host "Verifying signature..." -ForegroundColor Cyan
& $signtoolPath verify /pa $exeFullPath

if ($LASTEXITCODE -eq 0) {
    Write-Host "Signature verification successful!" -ForegroundColor Green
} else {
    Write-Warning "Signature verification failed"
}
