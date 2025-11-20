param(
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [string]$TargetVersion
)

# Database Migration Script for RescuePC Repairs
# Handles online schema migrations with zero downtime

$ErrorActionPreference = "Stop"

Write-Host "Database Migration Script" -ForegroundColor Green
Write-Host "Dry Run: $DryRun" -ForegroundColor Yellow
Write-Host "Force: $Force" -ForegroundColor Yellow

function Test-DatabaseConnection {
    Write-Host "Testing database connection..." -ForegroundColor Blue
    
    try {
        # Test basic connection
        npm run db:generate 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to generate Prisma client"
        }
        
        Write-Host "Database connection successful" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Database connection failed: $_" -ForegroundColor Red
        return $false
    }
}

function Get-PendingMigrations {
    Write-Host "Checking for pending migrations..." -ForegroundColor Blue
    
    $migrationsDir = "prisma\migrations"
    
    if (-not (Test-Path $migrationsDir)) {
        Write-Host "No migrations directory found" -ForegroundColor Yellow
        return @()
    }
    
    $pendingMigrations = Get-ChildItem $migrationsDir -Directory | Sort-Object Name
    
    if ($pendingMigrations.Count -eq 0) {
        Write-Host "No pending migrations found" -ForegroundColor Green
        return @()
    }
    
    Write-Host "Found $($pendingMigrations.Count) pending migrations:" -ForegroundColor Yellow
    $pendingMigrations | ForEach-Object { Write-Host "  - $($_.Name)" }
    
    return $pendingMigrations
}

function Backup-Database {
    Write-Host "Creating database backup..." -ForegroundColor Blue
    
    $backupFile = "backup_$(Get-Date -Format `"yyyyMMdd_HHmmss`").sql"
    
    try {
        # Extract connection details from DATABASE_URL
        $dbUrl = $env:DATABASE_URL
        if (-not $dbUrl) {
            throw "DATABASE_URL environment variable not set"
        }
        
        # Parse connection string (postgresql://user:password@host:port/database)
        if ($dbUrl -match "postgresql://([^:]+):([^@]+)@([^:]+):(\d+)/(.+)") {
            $user = $matches[1]
            $password = $matches[2]
            $dbHost = $matches[3]
            $port = $matches[4]
            $database = $matches[5]
            
            $env:PGPASSWORD = $password
            
            $backupCmd = "pg_dump -h $dbHost -p $port -U $user -d $database > $backupFile"
            Invoke-Expression $backupCmd
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Database backup created: $backupFile" -ForegroundColor Green
                return $backupFile
            } else {
                throw "pg_dump failed"
            }
        } else {
            throw "Invalid DATABASE_URL format"
        }
    } catch {
        Write-Host "Backup failed: $_" -ForegroundColor Red
        return $null
    }
}

function Invoke-Migration {
    param([string]$MigrationPath)
    
    Write-Host "Applying migration: $MigrationPath" -ForegroundColor Blue
    
    $migrationFile = Join-Path $MigrationPath "migration.sql"
    
    if (-not (Test-Path $migrationFile)) {
        throw "Migration file not found: $migrationFile"
    }
    
    try {
        # Extract connection details
        $dbUrl = $env:DATABASE_URL
        if ($dbUrl -match "postgresql://([^:]+):([^@]+)@([^:]+):(\d+)/(.+)") {
            $user = $matches[1]
            $password = $matches[2]
            $dbHost = $matches[3]
            $port = $matches[4]
            $database = $matches[5]
            
            $env:PGPASSWORD = $password
            
            # Apply migration
            $migrationCmd = "psql -h $dbHost -p $port -U $user -d $database -f $migrationFile"
            Invoke-Expression $migrationCmd
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Migration applied successfully" -ForegroundColor Green
                return $true
            } else {
                throw "Migration failed"
            }
        } else {
            throw "Invalid DATABASE_URL format"
        }
    } catch {
        Write-Host "Migration failed: $_" -ForegroundColor Red
        return $false
    }
}

function Test-MigrationImpact {
    param([string]$MigrationPath)
    
    Write-Host "Analyzing migration impact..." -ForegroundColor Blue
    
    $migrationFile = Join-Path $MigrationPath "migration.sql"
    $migrationContent = Get-Content $migrationFile
    
    $hasDestructiveChanges = $false
    $hasLongRunningOperations = $false
    
    foreach ($line in $migrationContent) {
        $line = $line.Trim().ToUpper()
        
        # Check for destructive operations
        if ($line -match "DROP|TRUNCATE|DELETE WHERE") {
            $hasDestructiveChanges = $true
            Write-Host "Destructive change detected: $line" -ForegroundColor Yellow
        }
        
        # Check for potentially long-running operations
        if ($line -match "ALTER TABLE.*ADD COLUMN.*DEFAULT|CREATE INDEX|UPDATE.*SET") {
            $hasLongRunningOperations = $true
            Write-Host "Potentially long-running operation: $line" -ForegroundColor Yellow
        }
    }
    
    if ($hasDestructiveChanges -or $hasLongRunningOperations) {
        Write-Host "Migration requires careful consideration" -ForegroundColor Yellow
        
        if (-not $Force) {
            Write-Host "Use -Force to proceed with potentially risky migration" -ForegroundColor Yellow
            return $false
        }
    }
    
    Write-Host "Migration analysis completed" -ForegroundColor Green
    return $true
}

function Main {
    try {
        # Check prerequisites
        if (-not (Test-DatabaseConnection)) {
            throw "Database connection failed"
        }
        
        # Get pending migrations
        $pendingMigrations = Get-PendingMigrations
        
        if ($pendingMigrations.Count -eq 0) {
            Write-Host "Database is up to date" -ForegroundColor Green
            return
        }
        
        # Create backup
        $backupFile = Backup-Database
        if (-not $backupFile -and -not $DryRun) {
            throw "Backup failed - cannot proceed with migration"
        }
        
        # Process each migration
        foreach ($migration in $pendingMigrations) {
            Write-Host "`nProcessing migration: $($migration.Name)" -ForegroundColor Cyan
            
            # Test migration impact
            if (-not (Test-MigrationImpact -MigrationPath $migration.FullName)) {
                continue
            }
            
            if ($DryRun) {
                Write-Host "Dry run: Would apply migration: $($migration.Name)" -ForegroundColor Yellow
                continue
            }
            
            # Apply migration
            if (-not (Invoke-Migration -MigrationPath $migration.FullName)) {
                Write-Host "Migration failed: $($migration.Name)" -ForegroundColor Red
                
                if ($backupFile) {
                    Write-Host "To restore from backup: psql -d rescuepc < $backupFile" -ForegroundColor Yellow
                }
                
                throw "Migration failed"
            }
        }
        
        # Regenerate Prisma client after successful migration
        if (-not $DryRun) {
            Write-Host "Regenerating Prisma client..." -ForegroundColor Blue
            npm run db:generate
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Prisma client regenerated" -ForegroundColor Green
            } else {
                Write-Host "Prisma client regeneration failed" -ForegroundColor Yellow
            }
        }
        
        Write-Host "`nMigration completed successfully!" -ForegroundColor Green
        
        if ($backupFile) {
            Write-Host "Backup file: $backupFile" -ForegroundColor Green
        }
        
    } catch {
        Write-Host "Migration failed: $_" -ForegroundColor Red
        exit 1
    }
}

# Run main function
Main

# SIG # Begin signature block
# MIIFfAYJKoZIhvcNAQcCoIIFbTCCBWkCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUidiIkyYY8gaTMBZXlwT55cvy
# 8/qgggMSMIIDDjCCAfagAwIBAgIQc6VPVBbWr69NGcDq7bD4HzANBgkqhkiG9w0B
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
# 9w0BCQQxFgQUw6gAvwkv3zcwyRMw+5jor03KvWcwDQYJKoZIhvcNAQEBBQAEggEA
# f3S7+DzyO1M1voboFuqe28ZYHBczaaFG0y7vnIdG9IyBrxCLPodD6rHwx/kt0rk6
# pHAqkKHf3FWHKupzONoUOCf/WLO+WTsZxOsm+cbaFf7MB3nvi2sfiLM3d24uJURw
# 90N2faC0klv3m0hlJSUFrdpX8YvHqnATqA85tjXZahXFZ6wcacStweat0UPjAo78
# J6blvWjLWeUwaKDTvkQlUkJNxX7L77x4Phzd4lkufIIXvoQ7OyxSNhHHXZCiabil
# AQAxUKoaTqGsfZKJfbMdpN/ZxZKaE+x065recpPJ6vHh/ZPq12dt81m0iG8jBnBC
# VgTj7plJMLaHhP/xQSBBTA==
# SIG # End signature block
