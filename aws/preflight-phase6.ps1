param([string] $Region = 'us-east-2')

$ErrorActionPreference = 'Stop'

function Require-Command([string] $Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is required for Phase 6. Install it before continuing."
    }
}

Require-Command 'aws'
Require-Command 'kubectl'
Require-Command 'eksctl'
Require-Command 'helm'
Require-Command 'docker'

Write-Host 'Checking AWS identity...'
$identity = aws sts get-caller-identity --output json | ConvertFrom-Json
if (-not $identity.Account) { throw 'AWS identity could not be resolved. Authenticate AWS CLI first.' }
Write-Host "AWS account: $($identity.Account)"
Write-Host "AWS principal: $($identity.Arn)"
Write-Host "Target region: $Region"

Write-Host 'Checking EBS CSI addon availability...'
aws eks describe-addon-versions --region $Region --query 'addons[?addonName==`aws-ebs-csi-driver`].addonVersions[0:3].{version:addonVersion,kubernetesVersions:compatibilities[].clusterVersion}' --output table

Write-Host 'Checking local Docker and disk state...'
docker version --format 'Docker server: {{.Server.Version}}'
$disk = Get-PSDrive C
Write-Host ("C: free space: {0:N1} GB" -f ($disk.Free / 1GB))
Write-Host 'Preflight passed. No AWS resources were created.'
