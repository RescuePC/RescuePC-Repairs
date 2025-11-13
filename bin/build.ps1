# Build script
param(
    [switch]$Sign,
    [ValidateSet("SelfSigned", "Commercial")]
    [string]$SignMethod = "SelfSigned",
    [string]$PfxPath,
    [string]$PfxPassword
)

Write-Host "Building EXE..." -ForegroundColor Yellow

ps2exe -inputFile ".\RescuePC_Launcher.ps1" -outputFile "..\RescuePC Repairs.exe" -icon "..\public\RescuePC_Icon.ico" -title "RescuePC Repairs" -description "Automated Windows repair toolkit" -version "2.0.0" -requireAdmin $true -noConsole $true

if (Test-Path "..\RescuePC Repairs.exe") {
    Write-Host "EXE built successfully!" -ForegroundColor Green

    # Optional code signing
    if ($Sign) {
        Write-Host "Code signing requested..." -ForegroundColor Cyan

        if ($SignMethod -eq "Commercial" -and -not $PfxPath) {
            Write-Warning "Commercial signing requires -PfxPath parameter. Using self-signed instead."
            $SignMethod = "SelfSigned"
        }

        & ".\sign-exe.ps1" -Method $SignMethod -ExePath "..\RescuePC Repairs.exe" -PfxPath $PfxPath -PfxPassword $PfxPassword
    }
} else {
    Write-Host "Build failed!" -ForegroundColor Red
}