param([int]$Port = 8767)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Python = Join-Path $Root '.venv\Scripts\pythonw.exe'
if (-not (Test-Path $Python)) { throw "Bridge pythonw not found: $Python; run setup-runtime.ps1" }
$Listening = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
if ($Listening) { Write-Output "already listening on 127.0.0.1:$Port"; exit 0 }
$Script = Join-Path $Root 'bridge_server.py'
Start-Process -FilePath $Python -ArgumentList @("`"$Script`"", "$Port") -WorkingDirectory $Root -WindowStyle Hidden
$Deadline = [DateTime]::UtcNow.AddSeconds(10)
do {
  Start-Sleep -Milliseconds 200
  try {
    $Client = [Net.Sockets.TcpClient]::new()
    $Client.Connect('127.0.0.1', $Port)
    $Client.Dispose()
    Write-Output "started on 127.0.0.1:$Port"
    exit 0
  } catch {}
} while ([DateTime]::UtcNow -lt $Deadline)
throw "Bridge did not start on 127.0.0.1:$Port; inspect $Root\logs\bridge-server.log"
