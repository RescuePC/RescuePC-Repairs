#requires -Version 5.1

<#
.SYNOPSIS
    SharePoint-based licensing module for RescuePC Repairs
.DESCRIPTION
    Validates licenses against SharePoint list instead of SQL database.
    Requires internet connection for license validation.
.NOTES
    This is a FREE solution using SharePoint + Power Automate.
    No API keys or paid services required.
#>

# SharePoint configuration - Update these values
$script:SharePointSiteUrl = "https://yourtenant.sharepoint.com/sites/RescuePC"
$script:ListName = "Licenses"
$script:ClientId = ""  # Leave empty for anonymous access if list is public

function Get-SharePointLicenses {
    <#
    .SYNOPSIS
        Query SharePoint list for license validation
    .PARAMETER LicenseKey
        The license key to validate
    .PARAMETER CustomerEmail
        Customer email for additional validation
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$LicenseKey,

        [Parameter(Mandatory = $false)]
        [string]$CustomerEmail
    )

    try {
        # Build REST API URL
        $apiUrl = "$($script:SharePointSiteUrl)/_api/web/lists/getbytitle('$($script:ListName)')/items"

        # Build filter query
        $filter = "LicenseKey eq '$LicenseKey'"
        if ($CustomerEmail) {
            $filter += " and CustomerEmail eq '$CustomerEmail'"
        }

        $queryUrl = $apiUrl + "?$filter=" + [System.Web.HttpUtility]::UrlEncode($filter)

        # Make REST call (anonymous if list allows)
        $headers = @{
            "Accept" = "application/json;odata=nometadata"
            "Content-Type" = "application/json"
        }

        if ($script:ClientId) {
            # Add authentication if needed
            $headers["Authorization"] = "Bearer $script:ClientId"
        }

        $response = Invoke-RestMethod -Uri $queryUrl -Headers $headers -Method Get

        if ($response.value -and $response.value.Count -gt 0) {
            $license = $response.value[0]

            # Check if license is valid
            $isValid = $license.Status -eq "issued"
            $isExpired = $false  # SharePoint licenses don't expire unless you add expiry logic

            return @{
                Valid = $isValid
                Product = $license.Product
                CustomerEmail = $license.CustomerEmail
                IssuedAt = [DateTime]::Parse($license.IssuedAt)
                Status = $license.Status
                Amount = $license.Amount
                Currency = $license.Currency
            }
        } else {
            return @{ Valid = $false }
        }

    } catch {
        Write-Warning "License validation failed: $($_.Exception.Message)"
        return @{ Valid = $false; Error = $_.Exception.Message }
    }
}

function Test-SharePointConnection {
    <#
    .SYNOPSIS
        Test connection to SharePoint licensing system
    #>
    try {
        $apiUrl = "$($script:SharePointSiteUrl)/_api/web/lists/getbytitle('$($script:ListName)')/items?$top=1"
        $response = Invoke-WebRequest -Uri $apiUrl -Method Get -TimeoutSec 10
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

function Get-LicenseTier {
    <#
    .SYNOPSIS
        Get license tier based on product name
    .PARAMETER Product
        Product name from SharePoint
    #>
    param([string]$Product)

    switch -Wildcard ($Product) {
        "*Basic*" { return "Basic" }
        "*Pro*" { return "Pro" }
        "*Enterprise*" { return "Enterprise" }
        "*Lifetime*" { return "Lifetime" }
        default { return "Basic" }
    }
}

function Validate-License {
    <#
    .SYNOPSIS
        Main license validation function
    .PARAMETER LicenseKey
        License key to validate
    .PARAMETER CustomerEmail
        Customer email (optional but recommended)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$LicenseKey,

        [Parameter(Mandatory = $false)]
        [string]$CustomerEmail
    )

    # Check internet connection first
    if (-not (Test-Connection -ComputerName "www.sharepoint.com" -Count 1 -Quiet)) {
        Write-Warning "No internet connection. License validation requires internet access."
        return @{ Valid = $false; Offline = $true }
    }

    # Test SharePoint connection
    if (-not (Test-SharePointConnection)) {
        Write-Warning "Cannot connect to licensing server. Please check your internet connection."
        return @{ Valid = $false; ConnectionError = $true }
    }

    # Validate license
    $result = Get-SharePointLicenses -LicenseKey $LicenseKey -CustomerEmail $CustomerEmail

    if ($result.Valid) {
        $tier = Get-LicenseTier -Product $result.Product
        return @{
            Valid = $true
            Tier = $tier
            Product = $result.Product
            CustomerEmail = $result.CustomerEmail
            IssuedAt = $result.IssuedAt
        }
    } else {
        return @{ Valid = $false; Reason = "Invalid license key or email combination" }
    }
}

# Export functions
Export-ModuleMember -Function Validate-License, Test-SharePointConnection, Get-LicenseTier
