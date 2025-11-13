# Test admin status
function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($user)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$isAdmin = Test-Administrator
Write-Host "Running as administrator: $isAdmin"

if (-not $isAdmin) {
    Write-Host "Not running as admin. Current user: $env:USERNAME"
    Write-Host "Computer: $env:COMPUTERNAME"
}
