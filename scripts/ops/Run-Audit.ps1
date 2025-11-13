param([int]$TimeoutSec=120,[int]$MaxLoops=2)
$ErrorActionPreference='Stop'
$root = Split-Path -Parent $PSCommandPath
$scriptsDir = Resolve-Path (Join-Path $root "..")
$logsDir = Join-Path $scriptsDir "logs\audit"; New-Item $logsDir -ItemType Directory -Force | Out-Null

function Get-RescueScripts {
  $scripts = Get-ChildItem $scriptsDir -Filter *.ps1 -File -Recurse |
    Where-Object { $_.Name -notin @('RescuePC_Launcher.ps1', 'deploy-production.ps1', 'setup-database.ps1', 'Run-Audit.ps1', 'log_rotation.ps1', 'sign-exe.ps1') } |
    Sort-Object FullName
  return $scripts
}

function Invoke-WithTimeout {
  param([scriptblock]$Script,[int]$TimeoutSec)
  $job = Start-Job -ScriptBlock $Script
  if (Wait-Job $job -Timeout $TimeoutSec) {
    $o = Receive-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -Force
    @{ExitCode=0;TimedOut=$false;Output=($o|Out-String)}
  } else {
    Stop-Job $job -Force; Remove-Job $job -Force
    @{ExitCode=124;TimedOut=$true;Output="Timed out"}
  }
}

function Test-RescueScript {
  param([IO.FileInfo]$Script,[int]$TimeoutSec)
  $content = Get-Content $Script.FullName -Raw
  $mode = if ($content -match '\-SelfTest') {'SelfTest'} elseif ($content -match '\-Help') {'Help'} elseif ($content -match '\-WhatIf') {'WhatIf'} else {'ParseOnly'}
  $start=(Get-Date)
  $path = $Script.FullName
  $scriptBlock = {
    switch ($mode) {
      'SelfTest' { & powershell -NoProfile -ExecutionPolicy Bypass -File $path -SelfTest }
      'Help'     { & powershell -NoProfile -ExecutionPolicy Bypass -File $path -Help }
      'WhatIf'   { & powershell -NoProfile -ExecutionPolicy Bypass -File $path -WhatIf }
      'ParseOnly'{ $null=[System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$null,[ref]$null); "Parsed OK" }
    }
  }.GetNewClosure()
  $r = Invoke-WithTimeout -TimeoutSec $TimeoutSec -Script $scriptBlock
  $log=[ordered]@{
    Script=$Script.Name; Path=$Script.FullName; Mode=$mode
    ExitCode=$r.ExitCode; TimedOut=$r.TimedOut; Output=$r.Output.Trim()
    DurationMs=[int](((Get-Date)-$start).TotalMilliseconds); Pass=($r.ExitCode -eq 0 -and -not $r.TimedOut)
  }
  $log | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $logsDir ("{0}.json" -f [IO.Path]::GetFileNameWithoutExtension($Script.Name)))
  $log
}

$loop=1;$final=@()
while($loop -le $MaxLoops){
  Write-Host "=== Audit Loop $loop/$MaxLoops ===" -ForegroundColor Cyan
  $results = @()
  foreach ($script in Get-RescueScripts) {
    $results += Test-RescueScript -Script $script -TimeoutSec $TimeoutSec
  }
  $final=$results
  $fails=$results | Where-Object { -not $_.Pass }
  $results | ForEach-Object {
    Write-Host ("[{0}] {1}  ({2} ms) [{3}]" -f ($(if($_.Pass){'PASS'}else{'FAIL'}),$_.Script,$_.DurationMs,$_.Mode)) -ForegroundColor ($(if($_.Pass){'Green'}else{'Red'}))
  }
  if(-not $fails){break}; $loop++
}
$md=@("# Audit Summary","| Script | Pass | Duration | Mode |","|---|---|---:|---|")
$final | ForEach-Object { $md+="| {0} | {1} | {2} | {3} |" -f $_.Script,($(if($_.Pass){'✅'}else{'❌'})),$_.DurationMs,$_.Mode }
$md | Set-Content (Join-Path $logsDir "SUMMARY.md")
if($final.Where({-not $_.Pass}).Count -gt 0){ exit 2 } else { exit 0 }