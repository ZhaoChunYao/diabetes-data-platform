$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonCommand = Get-Command python -ErrorAction SilentlyContinue

if ($null -eq $PythonCommand) {
    throw 'Python was not found on PATH. Install Python 3.8+ and reopen PowerShell.'
}

Write-Host 'Starting the Flask server on http://localhost:5001'
Write-Host 'Make sure MySQL database project_554 has been imported first.'

Push-Location (Join-Path $ProjectRoot 'backend')
try {
    & $PythonCommand.Source 'server_unified.py'
} finally {
    Pop-Location
}
