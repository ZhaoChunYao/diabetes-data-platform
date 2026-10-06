param(
    [string]$DbPassword = ''
)

$ErrorActionPreference = 'Stop'
$kubernetesDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $kubernetesDir
$dockerDir = Join-Path $projectDir 'docker'
$composeFile = Join-Path $dockerDir 'docker-compose.postgres-full.yml'

if ([string]::IsNullOrWhiteSpace($DbPassword)) {
    $DbPassword = $env:CS554_DB_PASSWORD
}
if ([string]::IsNullOrWhiteSpace($DbPassword)) {
    # Matches the local Compose lab default. Set CS554_DB_PASSWORD for a
    # different password; it is never written into a manifest file.
    $DbPassword = 'app_password'
}

Write-Host 'Checking the Kubernetes context...'
$context = kubectl config current-context 2>$null
if ([string]::IsNullOrWhiteSpace($context)) {
    throw 'kubectl has no current context. Enable Docker Desktop Kubernetes and select the docker-desktop context first.'
}

if (-not (kubectl get crd clusters.postgresql.cnpg.io 2>$null)) {
    throw 'CloudNativePG CRD is missing. Run .\install-cnpg.ps1 first.'
}

Write-Host 'Starting the verified full PostgreSQL Compose source on port 5434...'
Push-Location $dockerDir
try {
    docker compose -f $composeFile up -d db
} finally {
    Pop-Location
}

$sourceId = (docker compose -f $composeFile ps -q db).Trim()
if ([string]::IsNullOrWhiteSpace($sourceId)) {
    throw 'Could not find the full PostgreSQL source container.'
}

Write-Host 'Waiting for the source PostgreSQL health check...'
$sourceHealthy = $false
for ($attempt = 1; $attempt -le 120; $attempt++) {
    $sourceHealth = (docker inspect --format '{{.State.Health.Status}}' $sourceId 2>$null).Trim()
    if ($sourceHealth -eq 'healthy') {
        $sourceHealthy = $true
        break
    }
    if ($sourceHealth -eq 'unhealthy') {
        throw 'The full PostgreSQL Compose source is unhealthy. Check docker compose logs db.'
    }
    Start-Sleep -Seconds 5
}
if (-not $sourceHealthy) {
    throw 'Timed out waiting for the full PostgreSQL Compose source to become healthy.'
}

Write-Host 'Building the Flask image for the local Kubernetes cluster...'
docker build -f (Join-Path $dockerDir 'Dockerfile.postgres') -t cs554-app:k8s $dockerDir

kubectl apply -f (Join-Path $kubernetesDir '00-namespace.yaml')

Write-Host 'Creating or updating the local database Secret...'
kubectl create secret generic cs554-db-credentials `
    --namespace cs554 `
    --from-literal=username=app `
    --from-literal=password=$DbPassword `
    --dry-run=client `
    -o yaml | kubectl apply -f -

Write-Host 'Creating the two-instance CloudNativePG cluster and importing project_554...'
kubectl apply -f (Join-Path $kubernetesDir '20-cluster.yaml')
kubectl wait --for=condition=Ready cluster/cs554-postgres -n cs554 --timeout=60m

Write-Host 'Deploying Flask against the CloudNativePG read-write Service...'
kubectl apply -f (Join-Path $kubernetesDir '30-app.yaml')
kubectl rollout status deployment/cs554-app -n cs554 --timeout=10m

Write-Host ''
Write-Host 'Phase 3 deployment is ready.'
Write-Host 'Application: http://localhost:30003'
Write-Host 'Run .\verify.ps1 for the acceptance checks.'
