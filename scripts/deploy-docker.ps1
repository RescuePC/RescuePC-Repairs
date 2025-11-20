# RescuePC Repairs - Docker Deployment Script
# Production-ready deployment with security hardening

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "prod", "test")]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [switch]$ForceRebuild,
    
    [Parameter(Mandatory=$false)]
    [switch]$WithSSL,
    
    [Parameter(Mandatory=$false)]
    [string]$Domain = ""
)

# Error handling
$ErrorActionPreference = "Stop"

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARN" { "Yellow" }
            "SUCCESS" { "Green" }
            default { "White" }
        }
    )
}

# Check prerequisites
function Test-Prerequisites {
    Write-Log "Checking prerequisites..."
    
    # Check Docker
    try {
        $dockerVersion = docker --version
        Write-Log "Docker found: $dockerVersion"
    }
    catch {
        Write-Log "Docker not found. Please install Docker Desktop." -Level "ERROR"
        exit 1
    }
    
    # Check Docker Compose
    try {
        $composeVersion = docker-compose --version
        Write-Log "Docker Compose found: $composeVersion"
    }
    catch {
        Write-Log "Docker Compose not found. Please install Docker Compose." -Level "ERROR"
        exit 1
    }
    
    # Check if .env file exists
    $envFile = ".env.$Environment"
    if (-not (Test-Path $envFile)) {
        Write-Log "Environment file $envFile not found. Creating from template..." -Level "WARN"
        if (Test-Path ".env.example") {
            Copy-Item ".env.example" $envFile
            Write-Log "Created $envFile. Please update with your values." -Level "WARN"
        } else {
            Write-Log "No .env.example found. Please create $envFile manually." -Level "ERROR"
            exit 1
        }
    }
    
    Write-Log "Prerequisites check completed." -Level "SUCCESS"
}

# Generate SSL certificates (self-signed for development)
function New-SSLCertificates {
    param([string]$Domain)
    
    if (-not $WithSSL) { return }
    
    Write-Log "Generating SSL certificates..."
    
    $sslDir = "config/nginx/ssl"
    if (-not (Test-Path $sslDir)) {
        New-Item -ItemType Directory -Path $sslDir -Force
    }
    
    if ($Environment -eq "dev" -or [string]::IsNullOrEmpty($Domain)) {
        # Generate self-signed certificate for development
        try {
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 `
                -keyout "$sslDir/key.pem" `
                -out "$sslDir/cert.pem" `
                -subj "/C=US/ST=State/L=City/O=RescuePC/CN=localhost"
            
            Write-Log "Self-signed SSL certificates generated for development." -Level "SUCCESS"
        }
        catch {
            Write-Log "Failed to generate SSL certificates. Install OpenSSL or use manual certificates." -Level "WARN"
        }
    } else {
        Write-Log "For production, please provide valid SSL certificates for $Domain" -Level "WARN"
        Write-Log "Place cert.pem and key.pem in config/nginx/ssl/" -Level "WARN"
    }
}

# Build Docker images
function Build-Images {
    Write-Log "Building Docker images..."
    
    if ($ForceRebuild) {
        Write-Log "Force rebuilding images (no cache)..."
        docker-compose build --no-cache
    } else {
        docker-compose build
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Docker build failed." -Level "ERROR"
        exit 1
    }
    
    Write-Log "Docker images built successfully." -Level "SUCCESS"
}

# Deploy services
function Deploy-Services {
    Write-Log "Deploying services..."
    
    $composeFile = "docker-compose.yml"
    if ($Environment -eq "prod") {
        $composeFile = "docker-compose.prod.yml"
    }
    
    # Stop existing services
    Write-Log "Stopping existing services..."
    docker-compose -f $composeFile down
    
    # Start services
    Write-Log "Starting services..."
    docker-compose -f $composeFile up -d
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Deployment failed." -Level "ERROR"
        exit 1
    }
    
    Write-Log "Services deployed successfully." -Level "SUCCESS"
}

# Health check
function Test-Health {
    Write-Log "Performing health checks..."
    
    $maxAttempts = 30
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:3000/api/health" -UseBasicParsing -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                Write-Log "Application is healthy!" -Level "SUCCESS"
                $data = $response.Content | ConvertFrom-Json
                Write-Log "Version: $($data.version), Service: $($data.service)"
                return
            }
        }
        catch {
            # Continue trying
        }
        
        $attempt++
        Write-Log "Health check attempt $($attempt)/$($maxAttempts)..."
        Start-Sleep -Seconds 2
    }
    
    Write-Log "Health check failed after $maxAttempts attempts." -Level "ERROR"
    exit 1
}

# Security audit
function Invoke-SecurityAudit {
    Write-Log "Running security audit..."
    
    # Check for exposed ports
    Write-Log "Checking exposed ports..."
    $ports = netstat -an | findstr "LISTENING"
    Write-Log "Listening ports: $($ports.Count)"
    
    # Check Docker security
    Write-Log "Checking Docker container security..."
    $containers = docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}"
    Write-Log "Running containers:"
    Write-Host $containers
    
    # Check environment variables
    Write-Log "Checking for sensitive environment variables..."
    $envVars = docker-compose config
    if ($envVars -match "password|secret|key") {
        Write-Log "Sensitive environment variables found. Ensure they are properly secured." -Level "WARN"
    }
    
    Write-Log "Security audit completed." -Level "SUCCESS"
}

# Main execution
try {
    Write-Log "Starting RescuePC Repairs Docker deployment..."
    Write-Log "Environment: $Environment"
    Write-Log "Force Rebuild: $ForceRebuild"
    Write-Log "With SSL: $WithSSL"
    
    Test-Prerequisites
    New-SSLCertificates -Domain $Domain
    Build-Images
    Deploy-Services
    Test-Health
    Invoke-SecurityAudit
    
    Write-Log "Deployment completed successfully!" -Level "SUCCESS"
    Write-Log "Application is running at: http://localhost:3000"
    if ($WithSSL) {
        Write-Log "HTTPS endpoint: https://localhost"
    }
    
    # Show running containers
    Write-Log "Running containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}
catch {
    Write-Log "Deployment failed: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
