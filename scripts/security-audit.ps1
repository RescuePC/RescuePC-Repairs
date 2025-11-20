# RescuePC Repairs - Security Audit Script
# Comprehensive security scanning and hardening

param(
    [Parameter(Mandatory=$false)]
    [switch]$FixIssues,
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateReport,
    
    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "security-audit-report.json"
)

# Error handling
$ErrorActionPreference = "Stop"

# Logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            "CRITICAL" { "Magenta" }
            default { "White" }
        }
    )
}

# Initialize audit results
$auditResults = @{
    timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    environment = if ($env:NODE_ENV) { $env:NODE_ENV } else { "development" }
    issues = @()
    recommendations = @()
    score = 100
}

# Check file permissions
function Test-FilePermissions {
    Write-Log "Checking file permissions..."
    
    $sensitiveFiles = @(
        ".env*",
        "config/nginx/ssl/*",
        "secrets/*",
        "*.pem",
        "*.key"
    )
    
    foreach ($pattern in $sensitiveFiles) {
        $files = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $acl = Get-Acl $file.FullName
            $hasPublicAccess = $acl.Access | Where-Object { 
                $_.IdentityReference -match "Everyone|Users|BUILTIN\\Users" -and 
                ($_.FileSystemRights -match "FullControl|Modify|Write" -or $_.AccessControlType -eq "Allow")
            }
            
            if ($hasPublicAccess) {
                $issue = @{
                    type = "FILE_PERMISSION"
                    severity = "HIGH"
                    file = $file.FullName
                    description = "Sensitive file has excessive permissions"
                    recommendation = "Restrict file permissions to owner only"
                }
                $auditResults.issues += $issue
                $auditResults.score -= 10
                Write-Log "Permission issue found: $($file.FullName)" -Level "WARN"
                
                if ($FixIssues) {
                    try {
                        icacls $file.FullName /inheritance:r /grant:r "$($env:USERNAME):(F)"
                        Write-Log "Fixed permissions for: $($file.FullName)" -Level "SUCCESS"
                    }
                    catch {
                        Write-Log "Failed to fix permissions for: $($file.FullName)" -Level "ERROR"
                    }
                }
            }
        }
    }
}

# Check environment variables
function Test-EnvironmentVariables {
    Write-Log "Checking environment variables..."
    
    $envFiles = @(".env", ".env.local", ".env.production", ".env.docker")
    
    foreach ($envFile in $envFiles) {
        if (Test-Path $envFile) {
            $content = Get-Content $envFile
            $foundWeakSecrets = $false
            
            # Check for weak/default secrets
            $content | ForEach-Object {
                if ($_ -match "your_.*_secret|test_.*|default_.*|password123|admin123") {
                    $foundWeakSecrets = $true
                }
            }
            
            if ($foundWeakSecrets) {
                $issue = @{
                    type = "WEAK_SECRETS"
                    severity = "CRITICAL"
                    file = $envFile
                    description = "Weak or default secrets detected"
                    recommendation = "Generate strong, unique secrets"
                }
                $auditResults.issues += $issue
                $auditResults.score -= 20
                Write-Log "Weak secrets found in: $envFile" -Level "CRITICAL"
            }
            
            # Check for missing required variables
            $requiredVars = @("JWT_SECRET", "ENCRYPTION_KEY", "DATABASE_URL")
            $presentVars = $content | Where-Object { $_ -match "=" } | ForEach-Object { $_.Split('=')[0] }
            
            foreach ($reqVar in $requiredVars) {
                if ($reqVar -notin $presentVars) {
                    $issue = @{
                        type = "MISSING_ENV_VAR"
                        severity = "HIGH"
                        variable = $reqVar
                        description = "Required environment variable missing"
                        recommendation = "Set the required environment variable"
                    }
                    $auditResults.issues += $issue
                    $auditResults.score -= 15
                    Write-Log "Missing environment variable: $reqVar" -Level "WARN"
                }
            }
        }
    }
}

# Check Docker security
function Test-DockerSecurity {
    Write-Log "Checking Docker security..."
    
    # Check if Docker is running
    try {
        $dockerInfo = docker info --format "{{.SecurityOptions}}"
        if ($dockerInfo -notmatch "userns|seccomp|apparmor|selinux") {
            $issue = @{
                type = "DOCKER_SECURITY"
                severity = "MEDIUM"
                description = "Docker security options not enabled"
                recommendation = "Enable Docker security profiles (seccomp, AppArmor, SELinux)"
            }
            $auditResults.issues += $issue
            $auditResults.score -= 5
            Write-Log "Docker security options could be improved" -Level "WARN"
        }
        
        # Check running containers
        $containers = docker ps --format "{{.Names}}" | Out-String
        if ($containers -match "root") {
            $issue = @{
                type = "DOCKER_ROOT"
                severity = "HIGH"
                description = "Containers running as root"
                recommendation = "Run containers as non-root user"
            }
            $auditResults.issues += $issue
            $auditResults.score -= 10
            Write-Log "Containers running as root detected" -Level "WARN"
        }
    }
    catch {
        Write-Log "Docker not available for security check" -Level "WARN"
    }
}

# Check code security
function Test-CodeSecurity {
    Write-Log "Checking code security..."
    
    # Check for hardcoded secrets in source code
    $sourceDirs = @("src", "scripts", "app")
    $secretPatterns = @(
        "sk_test_|sk_live_",  # Stripe keys
        "re_",                # Resend keys
        "password\s*=\s*['`"][^'`"]+['`"]",
        "secret\s*=\s*['`"][^'`"]+['`"]",
        "api_key\s*=\s*['`"][^'`"]+['`"]"
    )
    
    foreach ($dir in $sourceDirs) {
        if (Test-Path $dir) {
            $files = Get-ChildItem -Path $dir -Recurse -Include "*.js", "*.ts", "*.tsx", "*.jsx", "*.ps1"
            
            foreach ($file in $files) {
                $content = Get-Content $file.FullName -Raw
                
                foreach ($pattern in $secretPatterns) {
                    if ($content -match $pattern) {
                        $issue = @{
                            type = "HARDCODED_SECRET"
                            severity = "CRITICAL"
                            file = $file.FullName
                            description = "Hardcoded secret detected"
                            recommendation = "Move secrets to environment variables"
                        }
                        $auditResults.issues += $issue
                        $auditResults.score -= 25
                        Write-Log "Hardcoded secret in: $($file.FullName)" -Level "CRITICAL"
                    }
                }
            }
        }
    }
}

# Check network security
function Test-NetworkSecurity {
    Write-Log "Checking network security..."
    
    # Check for open ports
    $listeningPorts = netstat -an | findstr "LISTENING"
    $suspiciousPorts = @("22", "3389", "5432", "3306")
    
    foreach ($port in $suspiciousPorts) {
        if ($listeningPorts -match ":$port\s") {
            $issue = @{
                type = "OPEN_PORT"
                severity = "MEDIUM"
                port = $port
                description = "Potentially sensitive port open"
                recommendation = "Ensure port is properly secured or firewalled"
            }
            $auditResults.issues += $issue
            $auditResults.score -= 5
            Write-Log "Suspicious port open: $port" -Level "WARN"
        }
    }
}

# Check dependencies for vulnerabilities
function Test-Dependencies {
    Write-Log "Checking dependencies..."
    
    if (Test-Path "package.json") {
        try {
            # Check for known vulnerable packages (basic check)
            $packageJson = Get-Content "package.json" | ConvertFrom-Json
            $vulnerablePackages = @(
                "lodash<4.17.21",
                "axios<0.21.1",
                "node-forge<1.3.0",
                "serialize-javascript<3.1.0"
            )
            
            foreach ($pkg in $vulnerablePackages) {
                $pkgName, $version = $pkg.Split('<')
                if ($packageJson.dependencies.PSObject.Properties.Name -contains $pkgName) {
                    $installedVersion = $packageJson.dependencies.$pkgName
                    Write-Log "Checking package: $pkgName version: $installedVersion" -Level "INFO"
                    # This is a simplified check - in production, use npm audit or similar tools
                }
            }
            
            Write-Log "Consider running 'npm audit' for detailed vulnerability analysis" -Level "INFO"
        }
        catch {
            Write-Log "Failed to analyze package.json" -Level "WARN"
        }
    }
}

# Generate recommendations
function New-Recommendations {
    Write-Log "Generating security recommendations..."
    
    $recommendations = @(
        @{
            category = "Authentication"
            priority = "HIGH"
            action = "Implement multi-factor authentication"
            description = "Add MFA for admin access and sensitive operations"
        },
        @{
            category = "Monitoring"
            priority = "MEDIUM"
            action = "Set up security logging and monitoring"
            description = "Implement centralized logging and real-time alerts"
        },
        @{
            category = "Backup"
            priority = "HIGH"
            action = "Implement secure backup strategy"
            description = "Regular, encrypted backups with tested recovery procedures"
        },
        @{
            category = "Updates"
            priority = "MEDIUM"
            action = "Regular security updates"
            description = "Establish a patch management process for dependencies"
        },
        @{
            category = "Testing"
            priority = "MEDIUM"
            action = "Security testing in CI/CD"
            description = "Integrate security scanning into deployment pipeline"
        }
    )
    
    $auditResults.recommendations = $recommendations
}

# Generate report
function Export-SecurityReport {
    if (-not $GenerateReport) { return }
    
    Write-Log "Generating security report..."
    
    $reportPath = Join-Path (Get-Location) $ReportPath
    $reportDir = Split-Path $reportPath -Parent
    
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    $auditResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Log "Security report saved to: $reportPath" -Level "SUCCESS"
    
    # Generate summary
    Write-Log "=== SECURITY AUDIT SUMMARY ===" -Level "SUCCESS"
    Write-Log "Security Score: $($auditResults.score)/100" -Level "SUCCESS"
    Write-Log "Issues Found: $($auditResults.issues.Count)" -Level "SUCCESS"
    Write-Log "Recommendations: $($auditResults.recommendations.Count)" -Level "SUCCESS"
    
    if ($auditResults.issues.Count -gt 0) {
        Write-Log "Critical Issues: $(($auditResults.issues | Where-Object { $_.severity -eq 'CRITICAL' }).Count)" -Level "CRITICAL"
        Write-Log "High Issues: $(($auditResults.issues | Where-Object { $_.severity -eq 'HIGH' }).Count)" -Level "ERROR"
        Write-Log "Medium Issues: $(($auditResults.issues | Where-Object { $_.severity -eq 'MEDIUM' }).Count)" -Level "WARN"
    }
}

# Main execution
try {
    Write-Log "Starting RescuePC Repairs Security Audit..."
    
    Test-FilePermissions
    Test-EnvironmentVariables
    Test-DockerSecurity
    Test-CodeSecurity
    Test-NetworkSecurity
    Test-Dependencies
    New-Recommendations
    Export-SecurityReport
    
    Write-Log "Security audit completed!" -Level "SUCCESS"
    Write-Log "Final Security Score: $($auditResults.score)/100" -Level "SUCCESS"
    
    if ($auditResults.score -lt 70) {
        Write-Log "Security score is below recommended threshold. Please address critical issues." -Level "WARN"
        exit 1
    } elseif ($auditResults.score -lt 85) {
        Write-Log "Security score is acceptable but could be improved." -Level "WARN"
    } else {
        Write-Log "Security score is good!" -Level "SUCCESS"
    }
}
catch {
    Write-Log "Security audit failed: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}

# SIG # Begin signature block
# MIIFfAYJKoZIhvcNAQcCoIIFbTCCBWkCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU/TlF9h9zp8q2L7b50YRQsBJo
# 7zKgggMSMIIDDjCCAfagAwIBAgIQc6VPVBbWr69NGcDq7bD4HzANBgkqhkiG9w0B
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
# 9w0BCQQxFgQUPykib+zUHqdlTGRba4+MvmeY1/kwDQYJKoZIhvcNAQEBBQAEggEA
# BRt8+z4uA/Mdbgpd3HpcpQuz6ILL6Q6DWuFBC8yw8Qc2g9kPUwPM+tb/ZMTQTh11
# KCje1RIBNWjuI2LYCWTT5c9ga0El+Im+cJjmOijzERYcKSJqORjUwylXYmQmUGnE
# UYam1YWtosCPR3QdNv0P/j1R1dTAYi6PyGwEnNlCAG8n2XFhm8BGqBaW3V5BZpkE
# r9wKOmkmtobEhP7KZwZ1LRJS3kdMTUihtb9X4QShqZ4/GDRj99WeILoG9SqZE70K
# baC/NUtyxZB42twE6ToSP/gc4a4of91TAM/064eqQeKN5TsAhe58STMVt+AJdH+d
# 26N6mFyt1cPEIUqrtuhhPA==
# SIG # End signature block
