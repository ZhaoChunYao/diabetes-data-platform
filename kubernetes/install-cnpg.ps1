$ErrorActionPreference = 'Stop'

# Pin the operator minor release so this lab is repeatable. The manifest is
# published by the CloudNativePG project and installs the CRDs plus operator.
$cnpgRelease = '1.30.0'
$operatorUrl = "https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.30/releases/cnpg-$cnpgRelease.yaml"

$context = kubectl config current-context 2>$null
if ([string]::IsNullOrWhiteSpace($context)) {
    throw 'kubectl has no current context. Enable Docker Desktop Kubernetes and select the docker-desktop context first.'
}

Write-Host "Installing CloudNativePG $cnpgRelease into context '$context'..."
kubectl apply --server-side -f $operatorUrl
kubectl rollout status deployment/cnpg-controller-manager -n cnpg-system --timeout=10m
kubectl get crd clusters.postgresql.cnpg.io

Write-Host 'CloudNativePG operator is ready.'
