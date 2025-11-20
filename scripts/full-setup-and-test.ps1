# Comprehensive Setup and Test Script for RescuePC
# This script sets up the database, starts the server, and tests everything

Write-Host "`nRescuePC Comprehensive Setup & Test`n" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

# Step 1: Database Setup
Write-Host "`nStep 1: Database Setup" -ForegroundColor Yellow

# Try to setup database with postgres user first
$postgresConn = "postgresql://postgres:postgres@localhost:5432/rescuepc"
$rescuepcConn = "postgresql://rescuepc_owner:Lacaze23!@localhost:5432/rescuepc"

Write-Host "  → Granting permissions to rescuepc_owner..." -ForegroundColor Gray
node -e "
const { Client } = require('pg');
(async () => {
  try {
    const client = new Client({ connectionString: '$postgresConn' });
    await client.connect();
    await client.query('GRANT ALL PRIVILEGES ON DATABASE rescuepc TO rescuepc_owner');
    await client.query('GRANT ALL ON SCHEMA public TO rescuepc_owner');
    await client.query('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO rescuepc_owner');
    await client.end();
    console.log('Permissions granted');
  } catch (err) {
    console.log('Could not grant permissions (may need manual setup):', err.message);
  }
})();
"

Write-Host "  → Creating database schema..." -ForegroundColor Gray
node scripts/setup-database.js

# Step 2: Start Dev Server (in background)
Write-Host "`nStep 2: Starting Development Server" -ForegroundColor Yellow
Write-Host "  → Starting Next.js dev server..." -ForegroundColor Gray

$serverJob = Start-Job -ScriptBlock {
    Set-Location "C:\Users\Tyler\Desktop\RescuePC Repairs"
    npm run dev 2>&1 | Out-Null
}

# Wait for server to start
Write-Host "  → Waiting for server to start..." -ForegroundColor Gray
Start-Sleep -Seconds 10

# Step 3: Run Tests
Write-Host "`nStep 3: Running Tests" -ForegroundColor Yellow
node scripts/test-all.js

# Step 4: Stop server
Write-Host "`nStopping server..." -ForegroundColor Yellow
Stop-Job $serverJob
Remove-Job $serverJob

Write-Host "`nSetup and testing complete!`n" -ForegroundColor Green


# SIG # Begin signature block
# MIIFfAYJKoZIhvcNAQcCoIIFbTCCBWkCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUE7OYDin2a89V7zQFSO3X1k3Q
# 3FGgggMSMIIDDjCCAfagAwIBAgIQc6VPVBbWr69NGcDq7bD4HzANBgkqhkiG9w0B
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
# 9w0BCQQxFgQUAhDHXA1qj5yGBL107U52AnHE9DYwDQYJKoZIhvcNAQEBBQAEggEA
# F181xzeEenTKDhyRQk612+R+Xw2G5S66hL+Cnf80xuD2+3eqZ52kXxmrt5YdeYKM
# Zw8VJKLLgJPScVh/EfzdW1A/Tuq4EhKoSS+Ijse9C53IlfS8TDfFzmPaMyQvJOln
# 8GX5LHMR5wC3dKQN7DIsJJ5Lky+9T5z66zN/v+SGt8Aqd9jIRrhB2oamJDWB6ibI
# aGMeSq1oiBEYpUitD8WK1wKS9d1bIPbnmXM/wpoMJaAD7kzABCPb3UzwAb+25W6I
# 82zNfLRAL+CrG/tflpBCdi147F2xw/ibwUpKa9LaZCkGRmjvlvD80R86JIZXJdUm
# 7f2P+HSBz41ZuDuVg3ZRWQ==
# SIG # End signature block
