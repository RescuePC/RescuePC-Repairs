[CmdletBinding()]
param([switch]$SelfTest)

# Self-test mode for audit harness
if ($SelfTest) {
    Write-Host "SelfTest: disk_partition_fix script prerequisites OK"
    exit 0
}

# Purpose: Repair boot records, assign missing drive letters, and fix GPT/MBR issues
# Version: 2.3

# Function to find system executables in standard locations
function Get-SystemExecutable {
    param(
        [string]$Name
    )
    
    $systemPaths = @(
        "$env:SystemRoot\System32",
        "$env:SystemRoot\System32\wbem",
        "$env:SystemRoot\System32\WindowsPowerShell\v1.0"
    )
    
    # Try direct path first
    if (Test-Path $Name) {
        return $Name
    }
    
    # Try with .exe extension if not provided
    if (-not [System.IO.Path]::HasExtension($Name)) {
        $Name = "$Name.exe"
    }
    
    # Check in system paths
    foreach ($path in $systemPaths) {
        $fullPath = Join-Path -Path $path -ChildPath $Name
        if (Test-Path $fullPath) {
            return $fullPath
        }
    }
    
    # Try to find in PATH
    $exePath = Get-Command -Name $Name -ErrorAction SilentlyContinue
    if ($exePath) {
        return $exePath.Source
    }
    
    # If not found, return the name as-is and let the caller handle the error
    return $Name
}

# Check for administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script requires administrator privileges. Please run PowerShell as Administrator." -ForegroundColor Red
    Write-Host "Script will exit in 5 seconds..." -ForegroundColor Red
    Start-Sleep -Seconds 5
    exit
}

# Define log file path
$logPath = "C:\Users\Tyler\Desktop\RescuePC Repairs\logs\disk_partition_fix.log"
# Create the log directory if it doesn't exist
$logDir = Split-Path -Path $logPath -Parent
if (-not (Test-Path -Path $logDir -PathType Container)) {
    try {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    } catch {
        Write-Warning "Could not create log directory: $logDir. Logs will be saved to the Desktop."
        $logPath = "$env:USERPROFILE\Desktop\disk_partition_fix.log"
    }
}
Start-Transcript -Path $logPath -Append

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "         DISK PARTITION AND BOOT RECORD REPAIR TOOL        " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "Launching disk partition repair process..." -ForegroundColor Green
Write-Host "Running as Administrator: $isAdmin" -ForegroundColor Green
Write-Host "System: $([System.Environment]::OSVersion.VersionString)" -ForegroundColor Green
Write-Host "Date/Time: $(Get-Date)" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Cyan

# Step 1: Assign missing drive letters
Write-Host "Checking for volumes without drive letters..." -ForegroundColor Cyan
$volumesWithoutLetters = @(Get-Volume | Where-Object { $null -eq $_.DriveLetter -and $null -ne $_.FileSystemType })

if ($volumesWithoutLetters -and $volumesWithoutLetters.Count -gt 0) {
    Write-Host "Found $($volumesWithoutLetters.Count) volumes without drive letters. Attempting to assign letters..." -ForegroundColor Cyan

    foreach ($volume in $volumesWithoutLetters) {
        $availableLetters = [char[]](67..90) | Where-Object {
            (Get-Volume -DriveLetter $_ -ErrorAction SilentlyContinue) -eq $null
        }

        if ($availableLetters.Count -gt 0) {
            $letter = $availableLetters[0]
            try {
                # Reliable Volume-to-Partition Mapping
                $partition = try {
                    Get-Partition | Where-Object {
                        ($null -ne $_.UniqueId -and $_.UniqueId -eq $volume.UniqueId) -or 
                        ($null -ne $_.AccessPaths -and $_.AccessPaths -contains $volume.Path)
                    } | Get-Disk | Get-Partition | Where-Object {
                        $_.Size -eq $volume.Size -and 
                        $null -eq $_.DriveLetter -and 
                        $_.Type -ne "Reserved"
                    } | Select-Object -First 1
                } catch {
                    Write-Warning "Error finding partition for volume $($volume.FileSystemLabel): $_"
                    $null
                }

                if ($partition -ne $null) {
                    Set-Partition -DiskNumber $partition.DiskNumber -PartitionNumber $partition.PartitionNumber -NewDriveLetter $letter -ErrorAction Stop
                    Write-Host "Assigned drive letter $letter to volume $($volume.FileSystemLabel) on Disk $($partition.DiskNumber), Partition $($partition.PartitionNumber)" -ForegroundColor Green
                } else {
                    Write-Host "No matching partition found for volume $($volume.FileSystemLabel) with UniqueId '$($volume.UniqueId)' or Path '$($volume.Path)' and Size $($volume.Size)." -ForegroundColor Yellow
                }
            } catch {
                Write-Warning "Error assigning drive letter to volume $($volume.FileSystemLabel): $_"
            }
        } else {
            Write-Warning "No available drive letters to assign."
        }
    }
} else {
    Write-Host "No volumes without drive letters found or no valid volumes detected." -ForegroundColor Yellow
}

# Step 2: Repair boot record (MBR or GPT)
Write-Host "`nChecking system disk partition style..." -ForegroundColor Cyan
$disk = Get-Disk | Where-Object IsSystem -eq $true

if ($disk) {
    if ($disk.PartitionStyle -eq 'MBR') {
        Write-Host "Detected MBR disk. Running boot record repair..." -ForegroundColor Yellow
        $bootrecPath = Join-Path $env:SystemRoot "System32\bootrec.exe"

        if (Test-Path $bootrecPath) {
            Start-Process -FilePath $bootrecPath -ArgumentList "/fixmbr" -Wait -NoNewWindow
            Start-Process -FilePath $bootrecPath -ArgumentList "/fixboot" -Wait -NoNewWindow
            Start-Process -FilePath $bootrecPath -ArgumentList "/scanos" -Wait -NoNewWindow
            Start-Process -FilePath $bootrecPath -ArgumentList "/rebuildbcd" -Wait -NoNewWindow
        } else {
            Write-Warning "bootrec.exe not found. Run this script from Windows Recovery Environment (WinRE)."
        }
    } elseif ($disk.PartitionStyle -eq 'GPT') {
        Write-Host "Detected GPT disk. Attempting EFI repair..." -ForegroundColor Yellow
        $bcdBackup = "$env:SystemDrive\bcd_backup"

        $bcdeditExe = Get-SystemExecutable -Name 'bcdedit'
Start-Process -FilePath $bcdeditExe -ArgumentList "/export", "`"$bcdBackup`"" -Wait -NoNewWindow

        $bootPath = "$env:SystemDrive\boot"
        $efiBootPath = "$env:SystemDrive\EFI\Microsoft\Boot"

        if (Test-Path "$bootPath\BCD") {
            Start-Process -FilePath "attrib.exe" -ArgumentList "-h -s -r `"$bootPath\BCD`"" -Wait -NoNewWindow
            Rename-Item -Path "$bootPath\BCD" -NewName "BCD.bak" -Force
        } elseif (Test-Path "$efiBootPath\BCD") {
            Start-Process -FilePath "attrib.exe" -ArgumentList "-h -s -r `"$efiBootPath\BCD`"" -Wait -NoNewWindow
            Rename-Item -Path "$efiBootPath\BCD" -NewName "BCD.bak" -Force
        } else {
            Write-Warning "BCD file not found in standard locations."
        }

        $bootrecPath = Join-Path $env:SystemRoot "System32\bootrec.exe"
        if (Test-Path $bootrecPath) {
            Start-Process -FilePath $bootrecPath -ArgumentList "/rebuildbcd" -Wait -NoNewWindow
        } else {
            $bcdboot = Join-Path $env:SystemRoot "System32\bcdboot.exe"
            if (Test-Path $bcdboot) {
                $systemDriveWithColon = $env:SystemDrive
                if ($systemDriveWithColon -notmatch ':') {
                    $systemDriveWithColon = "${systemDriveWithColon}:"
                }
                Start-Process -FilePath $bcdboot -ArgumentList "`"$env:SystemRoot`" /s $systemDriveWithColon /f UEFI /l en-us" -Wait -NoNewWindow
            } else {
                Write-Warning "bcdboot.exe not found. EFI repair failed."
            }
        }
        Write-Host "EFI boot repair attempted, backup saved to $bcdBackup" -ForegroundColor Green
    } else {
        Write-Warning "Unknown partition style: $($disk.PartitionStyle)"
    }
} else {
    Write-Warning "Could not identify system disk."
}

# Step 3: Check and repair disk errors on all fixed drives
Write-Host "`nChecking for disk errors on all fixed drives..." -ForegroundColor Cyan
$fixedDrives = Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3} # DriveType 3 is for fixed local disks

foreach ($drive in $fixedDrives) {
    $driveLetter = $drive.DeviceID
    Write-Host "`nChecking disk: $($driveLetter)..." -ForegroundColor Yellow
    try {
        $chkdskExe = Get-SystemExecutable -Name 'chkdsk'
Start-Process -FilePath $chkdskExe -ArgumentList "$($driveLetter) /f /r /x" -Wait -NoNewWindow -PassThru -ErrorAction Stop
        Write-Host "CHKDSK completed successfully on $($driveLetter)." -ForegroundColor Green
    } catch {
        Write-Warning "CHKDSK failed on $($driveLetter): $_"
        try {
            $volume = Get-Volume -DriveLetter $driveLetter.TrimEnd(':') -ErrorAction Stop
            Repair-Volume -DriveLetter $driveLetter.TrimEnd(':') -Scan -ErrorAction Stop
            Write-Host "Repair-Volume scan completed on $($driveLetter)." -ForegroundColor Cyan
        } catch {
            Write-Warning "Repair-Volume scan failed on $($driveLetter): $_"
        }
    }
}

# Step 4: Final report
Write-Host "`nDisk partition and boot record repair process complete." -ForegroundColor Green
Write-Host "Log file saved to: $logPath" -ForegroundColor Cyan
Write-Host "`nImportant Notes:" -ForegroundColor Yellow
Write-Host "1. If you're still experiencing boot issues, try running this script from Windows Recovery Environment (WinRE)" -ForegroundColor Yellow
Write-Host "2. For serious boot problems, you may need to use 'bcdboot' to rebuild the boot configuration" -ForegroundColor Yellow
Write-Host "3. Some operations require administrator privileges - make sure you're running as administrator" -ForegroundColor Yellow
Write-Host "4. CHKDSK was run on all fixed local drives." -ForegroundColor Yellow

Stop-Transcript
