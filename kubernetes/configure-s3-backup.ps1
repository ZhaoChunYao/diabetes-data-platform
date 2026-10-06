param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9][a-z0-9.-]+$')]
    [string] $Bucket,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9-]+$')]
    [string] $Region,

    [string] $Prefix = 'cs554/phase5',
    [string] $Namespace = 'cs554',
    [string] $ObjectStoreName = 'cs554-s3-store',
    [string] $SecretName = 'cs554-s3-credentials'
)

$ErrorActionPreference = 'Stop'

# Credentials are deliberately read from environment variables instead of
# command-line arguments. Use a dedicated least-privilege IAM principal; do
# not use the AWS root access key.
$accessKey = $env:CS554_AWS_ACCESS_KEY_ID
$secretKey = $env:CS554_AWS_SECRET_ACCESS_KEY
$sessionToken = $env:CS554_AWS_SESSION_TOKEN
if ([string]::IsNullOrWhiteSpace($accessKey) -or [string]::IsNullOrWhiteSpace($secretKey)) {
    throw 'Set CS554_AWS_ACCESS_KEY_ID and CS554_AWS_SECRET_ACCESS_KEY in this PowerShell session first.'
}

kubectl get crd objectstores.barmancloud.cnpg.io | Out-Null
kubectl get namespace $Namespace | Out-Null

Write-Host 'Creating/updating the Kubernetes Secret (secret values are not printed)...'
$secretArgs = @('create', 'secret', 'generic', $SecretName, '-n', $Namespace, "--from-literal=ACCESS_KEY_ID=$accessKey", "--from-literal=ACCESS_SECRET_KEY=$secretKey")
if (-not [string]::IsNullOrWhiteSpace($sessionToken)) {
    $secretArgs += "--from-literal=ACCESS_SESSION_TOKEN=$sessionToken"
}
$secretArgs += @('--dry-run=client', '-o', 'yaml')
& kubectl @secretArgs | kubectl apply -f - | Out-Null

$destination = "s3://$Bucket/$Prefix"
$objectStoreYaml = @"
apiVersion: barmancloud.cnpg.io/v1
kind: ObjectStore
metadata:
  name: $ObjectStoreName
  namespace: $Namespace
spec:
  retentionPolicy: 7d
  instanceSidecarConfiguration:
    env:
      - name: AWS_REGION
        value: $Region
      - name: AWS_DEFAULT_REGION
        value: $Region
  configuration:
    destinationPath: $destination
    s3Credentials:
      accessKeyId:
        name: $SecretName
        key: ACCESS_KEY_ID
      secretAccessKey:
        name: $SecretName
        key: ACCESS_SECRET_KEY
    wal:
      compression: gzip
"@

$objectStoreFile = Join-Path $env:TEMP 'cs554-objectstore.yaml'
Set-Content -LiteralPath $objectStoreFile -Value $objectStoreYaml -Encoding utf8
kubectl apply -f $objectStoreFile
Remove-Item -LiteralPath $objectStoreFile -Force

Write-Host 'Enabling S3 WAL archiving on the existing CloudNativePG cluster...'
$patch = '{"spec":{"plugins":[{"name":"barman-cloud.cloudnative-pg.io","isWALArchiver":true,"parameters":{"barmanObjectName":"' + $ObjectStoreName + '"}}]}}'
kubectl patch cluster cs554-postgres -n $Namespace --type merge -p $patch

Write-Host "S3 ObjectStore configured at $destination"
Write-Host 'The cluster may roll its PostgreSQL pods while the plugin sidecars are added.'
