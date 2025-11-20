param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("blue", "green")]
    [string]$TargetColor = "green",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipHealthCheck,
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "production"
)

# Blue-Green Deployment Script for RescuePC Repairs
# This script handles zero-downtime deployments using blue-green strategy

$ErrorActionPreference = "Stop"

Write-Host "Starting Blue-Green Deployment..." -ForegroundColor Green
Write-Host "Target Color: $TargetColor" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow

# Configuration
$COMPOSE_FILE = "docker-compose.blue-green.yml"
$HEALTH_CHECK_TIMEOUT = 300  # 5 minutes
$HEALTH_CHECK_INTERVAL = 10   # 10 seconds

function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Blue
    
    # Check Docker
    try {
        docker --version | Out-Null
        Write-Host "Docker is available" -ForegroundColor Green
    } catch {
        throw "Docker is not installed or not running"
    }
    
    # Check Docker Compose
    try {
        docker-compose --version | Out-Null
        Write-Host "Docker Compose is available" -ForegroundColor Green
    } catch {
        throw "Docker Compose is not installed"
    }
    
    # Check compose file exists
    if (-not (Test-Path $COMPOSE_FILE)) {
        Write-Host "Compose file not found: $COMPOSE_FILE, but continuing with dry run" -ForegroundColor Yellow
        if (-not $DryRun) {
            throw "Compose file not found: $COMPOSE_FILE"
        }
    }
    
    Write-Host "Prerequisites check passed" -ForegroundColor Green
}

function Get-CurrentActiveColor {
    Write-Host "Determining current active color..." -ForegroundColor Blue
    
    # Check nginx configuration for current target
    $nginxConfig = Get-Content "nginx\nginx.conf" -ErrorAction SilentlyContinue
    if ($null -eq $nginxConfig) {
        Write-Host "Nginx config not found, defaulting to blue" -ForegroundColor Yellow
        return "blue"
    }
    
    # Join all lines into a single string for regex matching
    $configText = $nginxConfig -join "`n"
    
    if ($configText -match 'set \$target_backend (\w+)') {
        $currentColor = $matches[1]
        Write-Host "Current active color: $currentColor" -ForegroundColor Yellow
        return $currentColor
    }
    
    # Default to blue if not found
    Write-Host "Could not determine current color, defaulting to blue" -ForegroundColor Yellow
    return "blue"
}

function Switch-NginxTraffic {
    param([string]$NewColor)
    
    if ($DryRun) {
        Write-Host "Dry run: Would switch Nginx traffic to $NewColor" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Switching Nginx traffic to $NewColor..." -ForegroundColor Blue
    
    $nginxConfig = Get-Content "nginx\nginx.conf"
    $newConfig = $nginxConfig -replace 'set \$target_backend \w+', "set `$target_backend $NewColor"
    
    $newConfig | Set-Content "nginx\nginx.conf"
    
    # Reload nginx
    docker-compose -f $COMPOSE_FILE exec nginx nginx -s reload
    
    Write-Host "Traffic switched to $NewColor" -ForegroundColor Green
}

function Test-HealthCheck {
    param([string]$Color)
    
    if ($DryRun) {
        Write-Host "Dry run: Would run health check on $Color environment" -ForegroundColor Yellow
        return $true
    }
    
    Write-Host "Running health check on $Color environment..." -ForegroundColor Blue
    
    $containerName = "app-$Color"
    $maxAttempts = $HEALTH_CHECK_TIMEOUT / $HEALTH_CHECK_INTERVAL
    $attempt = 0
    
    do {
        $attempt++
        Write-Host "Health check attempt $attempt/$maxAttempts..." -ForegroundColor Yellow
        
        try {
            $health = docker-compose -f $COMPOSE_FILE ps -q $containerName | ForEach-Object {
                docker inspect $_ --format='{{.State.Health.Status}}'
            }
            
            if ($health -eq "healthy") {
                Write-Host "$Color is healthy" -ForegroundColor Green
                return $true
            }
        } catch {
            Write-Host "Health check failed: $_" -ForegroundColor Red
        }
        
        Start-Sleep $HEALTH_CHECK_INTERVAL
    } while ($attempt -lt $maxAttempts)
    
    Write-Host "$Color failed health check after $HEALTH_CHECK_TIMEOUT seconds" -ForegroundColor Red
    return $false
}

function Invoke-ColorDeployment {
    param([string]$Color)
    
    if ($DryRun) {
        Write-Host "Dry run: Would deploy to $Color environment" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Deploying to $Color environment..." -ForegroundColor Blue
    
    # Build and start the target color
    docker-compose -f $COMPOSE_FILE build app-$Color
    docker-compose -f $COMPOSE_FILE up -d app-$Color
    
    # Wait for container to be ready
    Write-Host "Waiting for $Color to be ready..." -ForegroundColor Yellow
    Start-Sleep 30
    
    # Run health check unless skipped
    if (-not $SkipHealthCheck) {
        if (-not (Test-HealthCheck -Color $Color)) {
            if (-not $Force) {
                throw "Deployment failed health check. Use -Force to override."
            }
            Write-Host "Health check failed but proceeding due to -Force flag" -ForegroundColor Yellow
        }
    }
    
    Write-Host "$Color deployment completed" -ForegroundColor Green
}

function Main {
    try {
        Test-Prerequisites
        
        $currentColor = Get-CurrentActiveColor
        
        if ($currentColor -eq $TargetColor) {
            Write-Host "$TargetColor is already active. No action needed." -ForegroundColor Yellow
            return
        }
        
        # Deploy to target color
        Invoke-ColorDeployment -Color $TargetColor
        
        # Switch traffic
        Switch-NginxTraffic -NewColor $TargetColor
        
        # Verify new deployment
        if (-not $SkipHealthCheck) {
            if (-not (Test-HealthCheck -Color $TargetColor)) {
                Write-Host "New deployment failed health check after traffic switch!" -ForegroundColor Red
                Write-Host "Rolling back to $currentColor..." -ForegroundColor Yellow
                
                Switch-NginxTraffic -NewColor $currentColor
                throw "Deployment failed and was rolled back"
            }
        }
        
        Write-Host "Blue-green deployment completed successfully!" -ForegroundColor Green
        Write-Host "Active color: $TargetColor" -ForegroundColor Green
        
        # Optional: Stop the old environment after successful deployment
        if ($Force) {
            Write-Host "Stopping old environment ($currentColor)..." -ForegroundColor Yellow
            docker-compose -f $COMPOSE_FILE stop app-$currentColor
        }
        
    } catch {
        Write-Host "Deployment failed: $_" -ForegroundColor Red
        exit 1
    }
}

# Run main function
Main
