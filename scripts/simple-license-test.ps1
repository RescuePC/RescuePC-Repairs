# Simple test to verify owner license validation
$apiUrl = "http://localhost:3000/api/verify-license"
$email = "keeseetyler@yahoo.com"
$licenseKey = "RescuePC-2025"

$body = @{
    email = $email
    licenseKey = $licenseKey
} | ConvertTo-Json

Write-Host "Testing owner license validation..."
Write-Host "Email: $email"
Write-Host "License Key: $licenseKey"

try {
    $response = Invoke-RestMethod -Uri $apiUrl -Method POST -Body $body -ContentType "application/json" -TimeoutSec 10
    Write-Host "`n✅ API call successful!"
    
    $response | ConvertTo-Json -Depth 10 | Write-Host
    
    if ($response.valid -eq $true -and $response.license.isOwner -eq $true) {
        Write-Host "`n🎉 OWNER LICENSE VALIDATION SUCCESSFUL!"
        Write-Host "License ID: $($response.license.licenseId)"
        Write-Host "Plan: $($response.license.planName)"
        Write-Host "Is Owner: $($response.license.isOwner)"
        Write-Host "Expires: Never (Lifetime)"
        
        # Test cache directory creation
        $cacheDir = "$env:ProgramData\RescuePC"
        if (!(Test-Path $cacheDir)) {
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
            Write-Host "Created cache directory: $cacheDir"
        }
        
        Write-Host "`n✅ All tests passed! The owner license system is working correctly."
    } else {
        Write-Host "`n❌ License validation failed or not an owner license"
        Write-Host "Valid: $($response.valid)"
        Write-Host "Is Owner: $($response.license.isOwner)"
    }
}
catch {
    Write-Host "`n❌ Error: $($_.Exception.Message)"
}
