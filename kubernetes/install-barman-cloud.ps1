$ErrorActionPreference = 'Stop'

# Install the Barman Cloud plugin. The plugin's application version and its
# Helm chart version are different: chart 0.8.0 packages plugin 0.15.0.
# This script does not create AWS resources or modify/delete PostgreSQL PVCs.
$pluginVersion = '0.15.0'
$chartVersion = '0.8.0'

if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
    throw 'helm is required. Install Helm, then run this script again.'
}

$operatorImage = kubectl get deployment cnpg-controller-manager -n cnpg-system -o jsonpath='{.spec.template.spec.containers[0].image}'
if ($operatorImage -notmatch ':1\.(2[6-9]|3[0-9])') {
    throw "CloudNativePG 1.26 or newer is required. Found: $operatorImage"
}

Write-Host "Installing Barman Cloud Plugin $pluginVersion..."
$repoList = (helm repo list 2>$null | Out-String)
if ($repoList -notmatch '(?m)^cnpg\s') {
    helm repo add cnpg https://cloudnative-pg.github.io/charts
    if ($LASTEXITCODE -ne 0) { throw 'Could not add the CloudNativePG Helm repository.' }
}
helm repo update
if ($LASTEXITCODE -ne 0) { throw 'Could not update the CloudNativePG Helm repository.' }
helm upgrade --install plugin-barman-cloud cnpg/plugin-barman-cloud --namespace cnpg-system --create-namespace --version $chartVersion --wait --timeout 10m
if ($LASTEXITCODE -ne 0) { throw 'Barman Cloud Plugin Helm installation failed.' }

kubectl get crd objectstores.barmancloud.cnpg.io
if ($LASTEXITCODE -ne 0) { throw 'Barman Cloud Plugin did not install its ObjectStore CRD.' }
kubectl get pods -n cnpg-system | Select-String 'barman'
Write-Host "Barman Cloud Plugin $pluginVersion (Helm chart $chartVersion) is installed."
