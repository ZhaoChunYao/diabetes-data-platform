param(
    [string] $Repository = 'https://github.com/ZhaoChunYao/diabetes-data-platform.git',
    [string] $Branch = 'main',
    [string] $CommitMessage = 'Publish verified four-phase deployment project'
)

$ErrorActionPreference = 'Stop'
$source = $PSScriptRoot
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$staging = Join-Path $env:TEMP "diabetes-data-platform-publish-$stamp"

try {
    Write-Host "Cloning $Repository into a temporary staging directory..."
    git clone --branch $Branch $Repository $staging

    $items = Get-ChildItem -LiteralPath $staging -Force | Where-Object { $_.Name -ne '.git' }
    foreach ($item in $items) {
        Remove-Item -LiteralPath $item.FullName -Recurse -Force
    }

    $excludeDirectories = @(
        '.git', '.venv', '__pycache__', '.pytest_cache', 'dataset', 'sql_dump'
        # Screenshots are intentionally included as qualitative UI evidence.
    )
    $excludeFiles = @(
        'Windows PowerShell.txt', '*.pyc', '*.pyo', '*.secret', '.env', '.env.*',
        '*accessKeys*.csv', '*credentials*.csv', '*environment-final*.txt',
        'phase6-final-verification-*.txt'
    )

    $robocopyArgs = @($source, $staging, '/E', '/COPY:DAT', '/DCOPY:DAT', '/R:1', '/W:1')
    foreach ($directory in $excludeDirectories) { $robocopyArgs += '/XD'; $robocopyArgs += (Join-Path $source $directory) }
    foreach ($file in $excludeFiles) { $robocopyArgs += '/XF'; $robocopyArgs += (Join-Path $source $file) }
    & robocopy @robocopyArgs | Out-Host
    if ($LASTEXITCODE -gt 7) { throw "robocopy failed with exit code $LASTEXITCODE" }

    # Defense in depth: redact account-specific identifiers in the staging copy
    # even if a future local edit reintroduces them into a deployment template.
    Get-ChildItem -LiteralPath $staging -Recurse -File -Include '*.yaml', '*.yml', '*.json', '*.md', '*.ps1' | ForEach-Object {
        $text = Get-Content -LiteralPath $_.FullName -Raw
        $text = $text -replace 'arn:aws:iam::\d{12}:', 'arn:aws:iam::<account-id>:'
        $text = $text -replace '\b\d{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com', '<account-id>.dkr.ecr.<region>.amazonaws.com'
        $text = $text -replace 'arn:aws:s3:::[a-z0-9.-]+', 'arn:aws:s3:::<backup-bucket>'
        $text = $text -replace 's3://[a-z0-9.-]+/', 's3://<backup-bucket>/'
        [System.IO.File]::WriteAllText($_.FullName, $text)
    }

    git -C $staging add --all
    Write-Host 'Files that will be committed:'
    git -C $staging diff --cached --name-status
    git -C $staging diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw 'Git whitespace validation failed.' }

    git -C $staging commit -m $CommitMessage
    git -C $staging push origin $Branch
    Write-Host 'Public repository update completed.'
}
finally {
    if (Test-Path -LiteralPath $staging) {
        Remove-Item -LiteralPath $staging -Recurse -Force
    }
}
