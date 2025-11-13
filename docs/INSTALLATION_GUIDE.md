# RescuePC Repairs USB Toolkit - Installation Guide

## Overview

This installation guide will walk you through the process of setting up the RescuePC Repairs USB Toolkit on either a USB drive or local computer. The toolkit is designed to work 100% offline, but initial setup requires downloading some components.

## System Requirements

- Windows 10 or 11 (64-bit recommended)
- 4GB+ USB drive (8GB+ recommended for full driver packs)
- Administrator privileges for setup and usage
- Internet connection (for initial setup only)

## Initial Setup

### Method 1: Using the Setup Script (Recommended)

1. **Run the Setup Script**
   - Double-click on `SetupRescuePC Repairs.bat` in the root directory
   - This script will:
     - Create all necessary directories
     - Verify required scripts
     - Download driver installer (if missing)
     - Set up threat scanner (if missing)
     - Check for portable applications

2. **Import Drivers**
   - Run `ImportDrivers.bat` to download and set up basic drivers
   - Alternatively, run `ImportDriversFromISO.bat` if you have the 40GB AM-Driver ISO

3. **Verify Installation**
   - Run `VerifyToolkit.bat` to ensure all components are properly installed
   - Check the generated `script_verification_result.txt` file for any issues

### Method 2: Manual Setup

1. **Create Required Directories**
   - Ensure the following directories exist:
     - `/logs/repair_logs/`
     - `/logs/performance_logs/`
     - `/logs/threat_logs/`
     - `/config/`
     - `/tools/DriverPacks/drivers/`
     - `/tools/threat_analysis/scanner/definitions/`

2. **Set Up Driver Installer**
   - Run `scripts/simple_sdio_download.ps1` to download the driver installer
   - Or manually download SDIO from [sdi-tool.org](https://sdi-tool.org/) and place it in `tools/DriverPacks/SDI_tool.exe`

3. **Set Up Threat Scanner**
   - Run `scripts/clam_setup.ps1` to set up the threat scanner
   - Or manually download ClamAV portable from [clamav.net](https://www.clamav.net/downloads) and extract to `tools/threat_analysis/scanner/`

4. **Install Portable Applications**
   - Copy the following files to their respective locations:
     - `tools/portable_apps/processhacker.exe`
     - `tools/portable_apps/autoruns.exe`
     - `tools/portable_apps/revo_uninstaller.exe`
     - `tools/portable_apps/chntpw/chntpw.exe`

## Obtaining Additional Components

### Driver Packs

The following options are available for driver packs:

1. **Basic Drivers (Built-in)**
   - Run `ImportDrivers.bat` to download essential drivers
   - These will be stored in `tools/DriverPacks/drivers/`

2. **Full Driver Collection (11GB)**
   - Download the 40GB AM-Driver ISO from official sources
   - Run `ImportDriversFromISO.bat` to import from the ISO

### Portable Applications

These applications are used by the toolkit:

1. **Process Hacker**
   - Download from [processhacker.sourceforge.io](https://processhacker.sourceforge.io/)
   - Place in `tools/portable_apps/processhacker.exe`

2. **Autoruns**
   - Download from [Microsoft SysInternals](https://docs.microsoft.com/en-us/sysinternals/downloads/autoruns)
   - Place in `tools/portable_apps/autoruns.exe`

3. **Revo Uninstaller**
   - Download from [revouninstaller.com](https://www.revouninstaller.com/products/revo-uninstaller-free/)
   - Place in `tools/portable_apps/revo_uninstaller.exe`

4. **CHNTPW** (Password Reset)
   - Download from [chntpw project](https://github.com/rescatux/chntpw)
   - Place in `tools/portable_apps/chntpw/chntpw.exe`

## Moving to a USB Drive

To move the toolkit to a USB drive:

1. Format a USB drive with NTFS file system
2. Copy the entire RescuePC Repairs toolkit directory to the USB drive
3. On the USB drive, run `SetupRescuePC Repairs.bat` to ensure everything is properly set up
4. Run `VerifyToolkit.bat` to check for any missing components

## Running the Toolkit

1. **With Admin Rights** (Recommended)
   - Run `RunRescuePC RepairsAsAdmin.bat` to launch with full permissions

2. **Standard Launch**
   - Double-click `RescuePC Repairs_Launcher.bat` or `RescuePC Repairs_Launcher.ps1`

## Troubleshooting

### Missing Components

- Run `SetupRescuePC Repairs.bat` to automatically fix most issues
- Check `script_verification_result.txt` for specific missing files
- Download missing portable applications manually as needed

### Driver Installation Issues

- Run `CheckDrivers.bat` to verify driver integrity
- Try importing drivers using both methods (download and ISO)
- Make sure the USB drive has enough space for driver packs

### PowerShell Execution Policy

If PowerShell scripts won't run due to execution policy:

1. Right-click `RunRescuePC RepairsAsAdmin.bat` and select "Run as administrator"
2. Or manually set policy: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`

## Security Notes

- RescuePC Repairs never sends data online
- All operations are performed locally
- No personal data is collected or transmitted
- The toolkit requires admin rights for most repairs

---

For additional help, see the `README.md` file or contact the toolkit developer.

*RescuePC Repairs USB Toolkit v1.0 - Created by Tyler Keesee*

