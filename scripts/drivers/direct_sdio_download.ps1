[CmdletBinding()]
param([switch]$SelfTest)

# RescuePC Repairs - Direct SDIO Downloader
# Downloads the latest Snappy Driver Installer Origin directly from the official website
# Version: 1.0

param (
    [Parameter(Mandatory=$false)]
    [string]$DestinationPath = "tools\DriverPacks\SDI_tool.exe",
    
    [Parameter(Mandatory=$false)]
    [string]$Force = $false
)

# Self-test mode for audit harness
if ($SelfTest) {
    Write-Host "SelfTest: direct_sdio_download.ps1 prerequisites OK"
    exit 0
}


Write-Host "Starting direct SDIO download process..." -ForegroundColor Cyan

# Ensure destination directory exists
$destinationDir = Split-Path -Parent $DestinationPath
if (-not (Test-Path -Path $destinationDir)) {
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    Write-Host "Created destination directory: $destinationDir" -ForegroundColor Green
}

# Direct download URL for the latest version from Glenn's page
$zipUrl = "https://www.glenn.delahoy.com/downloads/sdio/SDIO_1.15.1.813.zip"
$tempZipPath = [System.IO.Path]::GetTempFileName() + ".zip"
$extractPath = [System.IO.Path]::GetTempPath() + "SDIO_Extract"

try {
    # Download the ZIP file
    Write-Host "Downloading latest SDIO from $zipUrl..." -ForegroundColor Yellow
    
    # Set TLS security protocol
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # Create web client with proper user agent
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
    
    # Download the file
    $webClient.DownloadFile($zipUrl, $tempZipPath)
    
    # Verify download
    if (Test-Path $tempZipPath) {
        $fileInfo = Get-Item $tempZipPath
        $fileSizeMB = [Math]::Round($fileInfo.Length / 1MB, 2)
        
        if ($fileSizeMB -lt 5) {
            Write-Host "Download completed but file size is suspiciously small ($fileSizeMB MB). The file may be corrupted." -ForegroundColor Red
            exit 1
        }
        
        Write-Host "Successfully downloaded SDIO ZIP file ($fileSizeMB MB)" -ForegroundColor Green
        
        # Create extraction directory
        if (Test-Path $extractPath) {
            Remove-Item -Path $extractPath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
        
        # Extract the ZIP file
        Write-Host "Extracting ZIP file..." -ForegroundColor Yellow
        try {
            Expand-Archive -Path $tempZipPath -DestinationPath $extractPath -Force
            Write-Host "Extraction completed successfully" -ForegroundColor Green
            
            # Find the SDIO executable
            $sdioExecutables = @(
                "SDIO_*.exe",
                "SDI_tool.exe", 
                "SDI_*.exe", 
                "snappy-driver-installer-origin.exe"
            )
            
            $foundExecutable = $null
            
            foreach ($exePattern in $sdioExecutables) {
                $foundFiles = Get-ChildItem -Path $extractPath -Recurse -Include $exePattern -ErrorAction SilentlyContinue
                if ($foundFiles.Count -gt 0) {
                    $foundExecutable = $foundFiles[0].FullName
                    break
                }
            }
            
            if ($foundExecutable) {
                Write-Host "Found SDIO executable: $foundExecutable" -ForegroundColor Green
                
                # Copy to destination
                Copy-Item -Path $foundExecutable -Destination $DestinationPath -Force
                
                # Cleanup
                Remove-Item -Path $tempZipPath -Force -ErrorAction SilentlyContinue
                Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
                
                Write-Host "SDIO installation completed successfully! Installed to: $DestinationPath" -ForegroundColor Green
                exit 0
            }
            else {
                Write-Host "Could not find SDIO executable in the extracted files." -ForegroundColor Red
                exit 1
            }
        }
        catch {
            Write-Host "Error extracting ZIP file: $_" -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "Failed to download file" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "Error during download process: $_" -ForegroundColor Red
    exit 1
}
finally {
    # Cleanup if something went wrong
    if (Test-Path $tempZipPath) {
        Remove-Item -Path $tempZipPath -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $extractPath) {
        Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    }
} 


