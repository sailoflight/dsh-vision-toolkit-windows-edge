$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Venv = Join-Path $Root '.venv'
$VenvPython = Join-Path $Venv 'Scripts\python.exe'
if (-not (Test-Path $VenvPython)) {
  $Candidates = @(
    (Join-Path $env:LOCALAPPDATA 'Python\bin\python.exe')
  )
  $Candidates += Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Python\pythoncore-*\python.exe') -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
  $Candidates += Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python*\python.exe') -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
  $Bootstrap = $Candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $Bootstrap) { throw 'No Windows base Python was found for the bridge venv' }
  & $Bootstrap -m venv $Venv
  if ($LASTEXITCODE -ne 0) { throw "venv creation failed with exit code $LASTEXITCODE" }
}
& $VenvPython -m pip install --disable-pip-version-check -r (Join-Path $Root 'requirements-browser.txt')
if ($LASTEXITCODE -ne 0) { throw "Playwright install failed with exit code $LASTEXITCODE" }
& $VenvPython -c "import importlib.metadata; print('bridge venv playwright=' + importlib.metadata.version('playwright'))"
if ($LASTEXITCODE -ne 0) { throw 'bridge venv Playwright verification failed' }
