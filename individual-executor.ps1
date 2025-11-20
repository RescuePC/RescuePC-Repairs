# RescuePC Repairs - Individual Component Executor
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

# Initialize logging
$LogFile = "logs\individual-execution-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$ErrorLogFile = "logs\individual-execution-errors-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

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

Write-Log "=== RESCUEPC REPAIRS - INDIVIDUAL EXECUTION TESTING ==="
Write-Log "Starting individual component execution"

# 1. EXECUTE POWERSHELL SCRIPTS INDIVIDUALLY
Write-Log "Phase 1: Executing PowerShell Scripts"

$PowerShellScripts = @(
    @{Name="RescuePC_Launcher"; Path="bin\RescuePC_Launcher.ps1"; Args=@()},
    @{Name="Build Script"; Path="bin\build.ps1"; Args=@()},
    @{Name="Deploy Production"; Path="scripts\build\deploy-production.ps1"; Args=@("-WhatIf")},
    @{Name="Setup Database"; Path="scripts\build\setup-database.ps1"; Args=@("-WhatIf")},
    @{Name="Deploy Blue-Green"; Path="scripts\deploy-blue-green.ps1"; Args=@("-WhatIf")},
    @{Name="Deploy Docker"; Path="scripts\deploy-docker.ps1"; Args=@("-WhatIf")},
    @{Name="Full Setup Test"; Path="scripts\full-setup-and-test.ps1"; Args=@("-WhatIf")},
    @{Name="Migrate Database"; Path="scripts\migrate-database.ps1"; Args=@("-WhatIf")},
    @{Name="Rebuild Services"; Path="scripts\repair\rebuild_windows_services.ps1"; Args=@("-WhatIf")},
    @{Name="Security Audit"; Path="scripts\security-audit.ps1"; Args=@("-GenerateReport")},
    @{Name="License Test"; Path="scripts\simple-license-test.ps1"; Args=@()},
    @{Name="Test Admin"; Path="test_admin.ps1"; Args=@()}
)

foreach ($scriptInfo in $PowerShellScripts) {
    $script = $scriptInfo.Path
    $name = $scriptInfo.Name
    $args = $scriptInfo.Args
    
    if (Test-Path $script) {
        Write-Log "Executing PowerShell script: $name ($script)"
        try {
            $argString = if ($args.Count -gt 0) { $args -join " " } else { "" }
            $command = "powershell -ExecutionPolicy Bypass -File `"$script`" $argString"
            Write-Log "Command: $command"
            
            $process = Start-Process -FilePath "powershell" -ArgumentList "-ExecutionPolicy Bypass -File `"$script`" $args" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "logs\$name-output.txt" -RedirectStandardError "logs\$name-errors.txt"
            
            if ($process.ExitCode -eq 0) {
                Write-Log "✓ Script executed successfully: $name"
                if (Test-Path "logs\$name-output.txt") {
                    $output = Get-Content "logs\$name-output.txt" -Raw
                    Write-Log "Output: $($output.Substring(0, [Math]::Min(200, $output.Length)))"
                }
            } else {
                Write-ErrorLog "Script execution failed with exit code $($process.ExitCode): $name" $name
                if (Test-Path "logs\$name-errors.txt") {
                    $errorOutput = Get-Content "logs\$name-errors.txt" -Raw
                    Write-ErrorLog "Error output: $($errorOutput.Substring(0, [Math]::Min(200, $errorOutput.Length)))" $name
                }
            }
        } catch {
            Write-ErrorLog "Script execution exception: $name - $($_.Exception.Message)" $name
        }
    } else {
        Write-ErrorLog "Script not found: $script" "FileSystem"
    }
}

# 2. EXECUTE BATCH FILES INDIVIDUALLY
Write-Log "Phase 2: Executing Batch Files"

$BatchFiles = @(
    @{Name="Test EXE"; Path="test_exe.bat"; Args=@()}
)

foreach ($batchInfo in $BatchFiles) {
    $batch = $batchInfo.Path
    $name = $batchInfo.Name
    $args = $batchInfo.Args
    
    if (Test-Path $batch) {
        Write-Log "Executing batch file: $name ($batch)"
        try {
            $argString = if ($args.Count -gt 0) { $args -join " " } else { "" }
            $process = Start-Process -FilePath "cmd" -ArgumentList "/c `"$batch`" $argString" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "logs\$name-output.txt" -RedirectStandardError "logs\$name-errors.txt"
            
            if ($process.ExitCode -eq 0) {
                Write-Log "✓ Batch file executed successfully: $name"
            } else {
                Write-ErrorLog "Batch file execution failed with exit code $($process.ExitCode): $name" $name
            }
        } catch {
            Write-ErrorLog "Batch file execution exception: $name - $($_.Exception.Message)" $name
        }
    } else {
        Write-ErrorLog "Batch file not found: $batch" "FileSystem"
    }
}

# 3. EXECUTE NODE.JS PROCESSES INDIVIDUALLY
Write-Log "Phase 3: Executing Node.js Processes"

$NodeProcesses = @(
    @{Name="Next.js Dev"; Command="npm run dev"; Args=@(); Timeout=30},
    @{Name="Next.js Build"; Command="npm run build"; Args=@(); Timeout=120},
    @{Name="Next.js Start"; Command="npm start"; Args=@(); Timeout=30},
    @{Name="Test Security"; Command="npm run test:security"; Args=@(); Timeout=60},
    @{Name="Test Security Fix"; Command="npm run test:security:fix"; Args=@(); Timeout=60}
)

foreach ($processInfo in $NodeProcesses) {
    $name = $processInfo.Name
    $command = $processInfo.Command
    $args = $processInfo.Args
    $timeout = $processInfo.Timeout
    
    Write-Log "Executing Node.js process: $name ($command)"
    try {
        $argString = if ($args.Count -gt 0) { $args -join " " } else { "" }
        $fullCommand = "$command $argString"
        
        Write-Log "Command: $fullCommand (Timeout: ${timeout}s)"
        
        $process = Start-Process -FilePath "cmd" -ArgumentList "/c $fullCommand" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "logs\$name-output.txt" -RedirectStandardError "logs\$name-errors.txt"
        
        if ($process.ExitCode -eq 0) {
            Write-Log "✓ Node.js process executed successfully: $name"
        } else {
            Write-ErrorLog "Node.js process execution failed with exit code $($process.ExitCode): $name" $name
        }
    } catch {
        Write-ErrorLog "Node.js process execution exception: $name - $($_.Exception.Message)" $name
    }
}

# 4. EXECUTE DATABASE OPERATIONS INDIVIDUALLY
Write-Log "Phase 4: Executing Database Operations"

$DatabaseOperations = @(
    @{Name="Prisma Generate"; Command="npx prisma generate"; Args=@()},
    @{Name="Prisma Validate"; Command="npx prisma validate"; Args=@()},
    @{Name="Prisma DB Push"; Command="npx prisma db push"; Args=@("--skip-generate")},
    @{Name="Database Tests"; Path="Database"; Command="npm test"; Args=@()}
)

foreach ($dbOp in $DatabaseOperations) {
    $name = $dbOp.Name
    $command = $dbOp.Command
    $args = $dbOp.Args
    $path = if ($dbOp.Path) { $dbOp.Path } else { "." }
    
    Write-Log "Executing database operation: $name ($command)"
    try {
        $originalLocation = Get-Location
        Set-Location $path
        
        $argString = if ($args.Count -gt 0) { $args -join " " } else { "" }
        $fullCommand = "$command $argString"
        
        $process = Start-Process -FilePath "cmd" -ArgumentList "/c $fullCommand" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "logs\$name-output.txt" -RedirectStandardError "logs\$name-errors.txt"
        
        Set-Location $originalLocation
        
        if ($process.ExitCode -eq 0) {
            Write-Log "✓ Database operation executed successfully: $name"
        } else {
            Write-ErrorLog "Database operation execution failed with exit code $($process.ExitCode): $name" $name
        }
    } catch {
        Set-Location $originalLocation
        Write-ErrorLog "Database operation execution exception: $name - $($_.Exception.Message)" $name
    }
}

# 5. EXECUTE DOCKER OPERATIONS INDIVIDUALLY
Write-Log "Phase 5: Executing Docker Operations"

$DockerOperations = @(
    @{Name="Docker Build"; Command="docker build"; Args=@("-t", "rescuepc-test", ".")},
    @{Name="Docker Compose Config"; Command="docker-compose"; Args=@("config")},
    @{Name="Docker Compose Prod Config"; Command="docker-compose"; Args=@("-f", "docker-compose.prod.yml", "config")},
    @{Name="Docker Compose Blue-Green Config"; Command="docker-compose"; Args=@("-f", "docker-compose.blue-green.yml", "config")}
)

foreach ($dockerOp in $DockerOperations) {
    $name = $dockerOp.Name
    $command = $dockerOp.Command
    $args = $dockerOp.Args
    
    Write-Log "Executing Docker operation: $name ($command)"
    try {
        $argString = $args -join " "
        $fullCommand = "$command $argString"
        
        $process = Start-Process -FilePath "cmd" -ArgumentList "/c $fullCommand" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "logs\$name-output.txt" -RedirectStandardError "logs\$name-errors.txt"
        
        if ($process.ExitCode -eq 0) {
            Write-Log "✓ Docker operation executed successfully: $name"
        } else {
            Write-ErrorLog "Docker operation execution failed with exit code $($process.ExitCode): $name" $name
        }
    } catch {
        Write-ErrorLog "Docker operation execution exception: $name - $($_.Exception.Message)" $name
    }
}

# 6. EXECUTE SECURITY AUDITS INDIVIDUALLY
Write-Log "Phase 6: Executing Security Audits"

$SecurityAudits = @(
    @{Name="Environment File Audit"; Command="Get-ChildItem"; Args=@("-Path", ".", "-Filter", ".env*", "-Recurse")},
    @{Name="Package Security Audit"; Command="npm audit"; Args=@()},
    @{Name="PowerShell Execution Policy"; Command="Get-ExecutionPolicy"; Args=@()},
    @{Name="Service Status"; Command="Get-Service"; Args=@()}
)

foreach ($audit in $SecurityAudits) {
    $name = $audit.Name
    $command = $audit.Command
    $args = $audit.Args
    
    Write-Log "Executing security audit: $name ($command)"
    try {
        $argString = $args -join " "
        $fullCommand = "$command $argString"
        
        $process = Start-Process -FilePath "powershell" -ArgumentList "-Command $fullCommand" -Wait -PassThru -NoNewWindow -RedirectStandardOutput "logs\$name-output.txt" -RedirectStandardError "logs\$name-errors.txt"
        
        if ($process.ExitCode -eq 0) {
            Write-Log "✓ Security audit executed successfully: $name"
        } else {
            Write-ErrorLog "Security audit execution failed with exit code $($process.ExitCode): $name" $name
        }
    } catch {
        Write-ErrorLog "Security audit execution exception: $name - $($_.Exception.Message)" $name
    }
}

# 7. FINAL SUMMARY
Write-Log "=== INDIVIDUAL EXECUTION SUMMARY ==="
Write-Log "Execution log saved to: $LogFile"
Write-Log "Error log saved to: $ErrorLogFile"

$logCount = (Get-Content $LogFile | Measure-Object).Lines
$errorCount = if (Test-Path $ErrorLogFile) { (Get-Content $ErrorLogFile | Measure-Object).Lines } else { 0 }

Write-Log "Total log entries: $logCount"
Write-Log "Total error entries: $errorCount"

# Generate summary report
$summaryReport = @"
# RescuePC Repairs - Individual Execution Summary Report
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Execution Statistics
- Total Log Entries: $logCount
- Total Error Entries: $errorCount
- Success Rate: $([Math]::Round((($logCount - $errorCount) / $logCount) * 100, 2))%

## Components Tested
- PowerShell Scripts: $($PowerShellScripts.Count)
- Batch Files: $($BatchFiles.Count)
- Node.js Processes: $($NodeProcesses.Count)
- Database Operations: $($DatabaseOperations.Count)
- Docker Operations: $($DockerOperations.Count)
- Security Audits: $($SecurityAudits.Count)

## Detailed Results
"@

Add-Content -Path "logs\execution-summary-$(Get-Date -Format 'yyyyMMdd-HHmmss').md" -Value $summaryReport

if ($errorCount -eq 0) {
    Write-Log "🎉 ALL INDIVIDUAL EXECUTIONS COMPLETED SUCCESSFULLY"
} else {
    Write-Log "⚠ INDIVIDUAL EXECUTIONS COMPLETED WITH $errorCount ERRORS - CHECK ERROR LOG"
}

Write-Log "=== END INDIVIDUAL EXECUTION TESTING ==="
