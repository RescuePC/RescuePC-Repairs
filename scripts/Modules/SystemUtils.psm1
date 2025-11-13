# SystemUtils.psm1 - Provides absolute paths to critical system executables

function Get-SystemExecutable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('sfc','dism','chkdsk','sc.exe','powershell','cmd','reg','net','bcdedit')]
        [string]$Name
    )
    $system32 = Join-Path $env:SystemRoot 'System32'
    $sysnative = if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        Join-Path $env:SystemRoot 'sysnative'
    } else {
        $system32
    }
    switch ($Name.ToLower()) {
        'sfc'      { return Join-Path $system32 'sfc.exe' }
        'dism'     { return Join-Path $system32 'dism.exe' }
        'chkdsk'   { return Join-Path $system32 'chkdsk.exe' }
        'sc.exe'   { return Join-Path $system32 'sc.exe' }
        'powershell' { return Join-Path $system32 'WindowsPowerShell\v1.0\powershell.exe' }
        'cmd'      { return Join-Path $system32 'cmd.exe' }
        'reg'      { return Join-Path $system32 'reg.exe' }
        'net'      { return Join-Path $system32 'net.exe' }
        'bcdedit'  { return Join-Path $system32 'bcdedit.exe' }
        default    { throw "Unknown system executable: $Name" }
    }
}

Export-ModuleMember -Function Get-SystemExecutable
