param([switch]$Uninstall, [int]$Port = 8767)
$ErrorActionPreference = 'Stop'
$TaskName = 'DshVisionToolkitWindowsEdge'
if ($Uninstall) {
  if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Output "removed scheduled task $TaskName"
  } else {
    Write-Output "scheduled task $TaskName not present"
  }
  exit 0
}
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Python = Join-Path $Root '.venv\Scripts\pythonw.exe'
if (-not (Test-Path $Python)) { throw "Bridge pythonw not found: $Python; run setup-runtime.ps1" }
$Bridge = Join-Path $Root 'bridge_server.py'
$Action = New-ScheduledTaskAction -Execute $Python -Argument ('"{0}" {1}' -f $Bridge, $Port) -WorkingDirectory $Root
$Trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$Settings = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Days 3650) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "DSH WSL Windows Edge screenshot bridge on 127.0.0.1:$Port" -Force | Out-Null
Write-Output "registered scheduled task $TaskName with private pythonw"
& (Join-Path $Root 'start-bridge.ps1') -Port $Port
