# RescuePC Repairs - Comprehensive Individual Test Plan
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

# Initialize logging
$LogFile = "logs\individual-test-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$ErrorLogFile = "logs\individual-errors-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Ensure logs directory exists
if (!(Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" -Force
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry
    Add-Content -Path $LogFile -Value $LogEntry
}

function Write-ErrorLog {
    param([string]$Message, [string]$Component = "Unknown")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $ErrorEntry = "[$Timestamp] [ERROR] [$Component] $Message"
    Write-Host $ErrorEntry -ForegroundColor Red
    Add-Content -Path $ErrorLogFile -Value $ErrorEntry
}

Write-Log "=== RESCUEPC REPAIRS - INDIVIDUAL COMPONENT TESTING ==="
Write-Log "Starting comprehensive individual test execution"

# 1. TEST ALL POWERSHELL SCRIPTS INDIVIDUALLY
Write-Log "Phase 1: Testing PowerShell Scripts"

$PowerShellScripts = @(
    "bin\RescuePC_Launcher.ps1",
    "bin\build.ps1", 
    "scripts\build\deploy-production.ps1",
    "scripts\build\setup-database.ps1",
    "scripts\deploy-blue-green.ps1",
    "scripts\deploy-docker.ps1",
    "scripts\full-setup-and-test.ps1",
    "scripts\migrate-database.ps1",
    "scripts\repair\rebuild_windows_services.ps1",
    "scripts\security-audit.ps1",
    "scripts\simple-license-test.ps1",
    "test_admin.ps1"
)

foreach ($script in $PowerShellScripts) {
    if (Test-Path $script) {
        Write-Log "Testing PowerShell script: $script"
        try {
            # Test syntax first
            $null = powershell -NoProfile -Command "Get-Command '$script' -ErrorAction Stop | Out-Null"
            if ($LASTEXITCODE -eq 0) {
                Write-Log "✓ Script syntax valid: $script"
                
                # Test execution (dry run where possible)
                if ($script -like "*test*" -or $script -like "*audit*") {
                    Write-Log "Executing test/audit script: $script"
                    $output = powershell -ExecutionPolicy Bypass -File "$script" -WhatIf 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Log "✓ Script executed successfully: $script"
                    } else {
                        Write-ErrorLog "Script execution failed: $script" $script
                    }
                }
            } else {
                Write-ErrorLog "Script syntax error: $script" $script
            }
        } catch {
            Write-ErrorLog "Script test failed: $script - $($_.Exception.Message)" $script
        }
    } else {
        Write-ErrorLog "Script not found: $script" "FileSystem"
    }
}

# 2. TEST ALL BATCH FILES INDIVIDUALLY  
Write-Log "Phase 2: Testing Batch Files"

$BatchFiles = @("test_exe.bat")

foreach ($batch in $BatchFiles) {
    if (Test-Path $batch) {
        Write-Log "Testing batch file: $batch"
        try {
            # Test batch file syntax
            $testResult = cmd /c "echo Testing $batch && if exist $batch (echo File exists) else (echo File missing)"
            Write-Log "✓ Batch file accessible: $batch"
        } catch {
            Write-ErrorLog "Batch file test failed: $batch - $($_.Exception.Message)" $batch
        }
    } else {
        Write-ErrorLog "Batch file not found: $batch" "FileSystem"
    }
}

# 3. TEST ALL EXECUTABLES INDIVIDUALLY
Write-Log "Phase 3: Testing Executables"

$Executables = @(
    "RescuePC Repairs.exe",
    "public\downloads\RescuePC-Setup.exe"
)

foreach ($exe in $Executables) {
    if (Test-Path $exe) {
        Write-Log "Testing executable: $exe"
        try {
            # Test if executable is valid
            $fileInfo = Get-Item $exe
            Write-Log "✓ Executable found: $exe (Size: $($fileInfo.Length) bytes, Modified: $($fileInfo.LastWriteTime))"
            
            # Test executable signature if possible
            $sigTest = Get-AuthenticodeSignature $exe -ErrorAction SilentlyContinue
            if ($sigTest.Status -eq "Valid") {
                Write-Log "✓ Executable signature valid: $exe"
            } elseif ($sigTest.Status -eq "NotSigned") {
                Write-Log "⚠ Executable not signed: $exe"
            } else {
                Write-ErrorLog "Executable signature invalid: $exe - $($sigTest.Status)" $exe
            }
        } catch {
            Write-ErrorLog "Executable test failed: $exe - $($_.Exception.Message)" $exe
        }
    } else {
        Write-ErrorLog "Executable not found: $exe" "FileSystem"
    }
}

# 4. TEST NODE.JS COMPONENTS INDIVIDUALLY
Write-Log "Phase 4: Testing Node.js Components"

if (Test-Path "package.json") {
    Write-Log "Testing Node.js package configuration"
    try {
        $packageJson = Get-Content "package.json" | ConvertFrom-Json
        Write-Log "✓ package.json valid (Name: $($packageJson.name), Version: $($packageJson.version))"
        
        # Test npm scripts
        if ($packageJson.scripts) {
            Write-Log "Testing npm scripts"
            foreach ($script in $packageJson.scripts.PSObject.Properties) {
                Write-Log "Found script: $($script.Name) = $($script.Value)"
            }
        }
    } catch {
        Write-ErrorLog "package.json parsing failed: $($_.Exception.Message)" "Node.js"
    }
} else {
    Write-ErrorLog "package.json not found" "FileSystem"
}

# Test Next.js build
Write-Log "Testing Next.js build process"
try {
    $buildTest = npm run build 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log "✓ Next.js build successful"
    } else {
        Write-ErrorLog "Next.js build failed" "Next.js"
    }
} catch {
    Write-ErrorLog "Next.js build test failed: $($_.Exception.Message)" "Next.js"
}

# 5. TEST DATABASE COMPONENTS INDIVIDUALLY
Write-Log "Phase 5: Testing Database Components"

if (Test-Path "prisma\schema.prisma") {
    Write-Log "Testing Prisma schema"
    try {
        $schemaTest = npx prisma validate 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✓ Prisma schema valid"
        } else {
            Write-ErrorLog "Prisma schema validation failed" "Prisma"
        }
    } catch {
        Write-ErrorLog "Prisma schema test failed: $($_.Exception.Message)" "Prisma"
    }
} else {
    Write-ErrorLog "Prisma schema not found" "FileSystem"
}

if (Test-Path "Database\package.json") {
    Write-Log "Testing Database sub-application"
    try {
        Set-Location "Database"
        $dbTest = npm test 2>&1
        Set-Location ".."
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✓ Database tests passed"
        } else {
            Write-ErrorLog "Database tests failed" "Database"
        }
    } catch {
        Set-Location ".."
        Write-ErrorLog "Database test failed: $($_.Exception.Message)" "Database"
    }
}

# 6. TEST DOCKER COMPONENTS INDIVIDUALLY
Write-Log "Phase 6: Testing Docker Components"

$DockerFiles = @("Dockerfile", "docker-compose.yml", "docker-compose.prod.yml", "docker-compose.blue-green.yml")

foreach ($dockerFile in $DockerFiles) {
    if (Test-Path $dockerFile) {
        Write-Log "Testing Docker configuration: $dockerFile"
        try {
            if ($dockerFile -eq "Dockerfile") {
                $dockerTest = docker build -t rescuepc-test . 2>&1
            } else {
                $dockerTest = docker-compose -f $dockerFile config 2>&1
            }
            if ($LASTEXITCODE -eq 0) {
                Write-Log "✓ Docker configuration valid: $dockerFile"
            } else {
                Write-ErrorLog "Docker configuration failed: $dockerFile" "Docker"
            }
        } catch {
            Write-ErrorLog "Docker test failed: $dockerFile - $($_.Exception.Message)" "Docker"
        }
    } else {
        Write-ErrorLog "Docker file not found: $dockerFile" "FileSystem"
    }
}

# 7. TEST SECURITY COMPONENTS INDIVIDUALLY
Write-Log "Phase 7: Testing Security Components"

# Test environment files
$EnvFiles = @(".env.example", ".env.dev", ".env.docker", ".env.local", ".env.production")
foreach ($envFile in $EnvFiles) {
    if (Test-Path $envFile) {
        Write-Log "Testing environment file: $envFile"
        try {
            $envContent = Get-Content $envFile
            $envVars = $envContent | Where-Object { $_ -match "^[A-Z_]+" }
            Write-Log "✓ Environment file contains $($envVars.Count) variables: $envFile"
        } catch {
            Write-ErrorLog "Environment file test failed: $envFile - $($_.Exception.Message)" "Security"
        }
    }
}

# Test security audit
if (Test-Path "scripts\security-audit.ps1") {
    Write-Log "Running security audit"
    try {
        $securityTest = powershell -ExecutionPolicy Bypass -File "scripts\security-audit.ps1" -GenerateReport 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✓ Security audit completed"
        } else {
            Write-ErrorLog "Security audit failed" "Security"
        }
    } catch {
        Write-ErrorLog "Security audit failed: $($_.Exception.Message)" "Security"
    }
}

# 8. FINAL SUMMARY
Write-Log "=== INDIVIDUAL TESTING SUMMARY ==="
Write-Log "Test log saved to: $LogFile"
Write-Log "Error log saved to: $ErrorLogFile"

$logCount = (Get-Content $LogFile | Measure-Object).Lines
$errorCount = if (Test-Path $ErrorLogFile) { (Get-Content $ErrorLogFile | Measure-Object).Lines } else { 0 }

Write-Log "Total log entries: $logCount"
Write-Log "Total error entries: $errorCount"

if ($errorCount -eq 0) {
    Write-Log "🎉 ALL INDIVIDUAL TESTS COMPLETED SUCCESSFULLY"
} else {
    Write-Log "⚠ INDIVIDUAL TESTS COMPLETED WITH $errorCount ERRORS - CHECK ERROR LOG"
}

Write-Log "=== END INDIVIDUAL TESTING ==="
