param(
    [string] $Region = 'us-east-2',
    [string] $Repository = 'cs554-app',
    [string] $Tag = 'phase6',
    [string] $ProjectRoot = (Join-Path $PSScriptRoot '..')
)

$ErrorActionPreference = 'Stop'
$identity = aws sts get-caller-identity --output json | ConvertFrom-Json
$account = $identity.Account
if ([string]::IsNullOrWhiteSpace($account)) { throw 'AWS identity could not be resolved.' }

$registry = "$account.dkr.ecr.$Region.amazonaws.com"
$image = "$registry/$Repository`:$Tag"
$dockerRoot = (Resolve-Path (Join-Path $ProjectRoot 'docker')).Path
$dockerfile = Join-Path $dockerRoot 'Dockerfile.postgres'

aws ecr describe-repositories --repository-names $Repository --region $Region *> $null
if ($LASTEXITCODE -ne 0) {
    aws ecr create-repository --repository-name $Repository --region $Region --image-scanning-configuration scanOnPush=true | Out-Null
}

$password = aws ecr get-login-password --region $Region
if ($LASTEXITCODE -ne 0) { throw 'Could not obtain the ECR login password.' }
$password | docker login --username AWS --password-stdin $registry
if ($LASTEXITCODE -ne 0) { throw 'Docker login to ECR failed. Run this from a PowerShell that can access Docker Desktop.' }

docker build --file $dockerfile --tag $image $dockerRoot
if ($LASTEXITCODE -ne 0) { throw 'Docker build failed.' }
docker push $image
if ($LASTEXITCODE -ne 0) { throw 'Docker push failed.' }
Write-Host "ECR image: $image"
