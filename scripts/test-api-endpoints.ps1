param(
    [string]$NodeEnv = "development"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "=== RescuePC API Endpoint Test ===" -ForegroundColor Cyan
Write-Host "Repository: $repoRoot"
Write-Host "NODE_ENV=$NodeEnv"

$env:NODE_ENV = $NodeEnv

try {
    npm run test:api
    $exitCode = $LASTEXITCODE
}
catch {
    Write-Error "API test script threw an exception: $_"
    $exitCode = 1
}

if ($exitCode -ne 0) {
    Write-Error "API endpoint tests reported failures. See logs\\nextjs-test-results.log for details."
}
else {
    Write-Host "API endpoint tests completed successfully." -ForegroundColor Green
}

exit $exitCode
