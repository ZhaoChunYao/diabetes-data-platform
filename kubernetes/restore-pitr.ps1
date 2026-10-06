param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}T.*(Z|[+-]\d{2}:\d{2})$')]
    [string] $TargetTime,
    [string] $Namespace = 'cs554',
    [string] $RestoreClusterName = 'cs554-pitr-restore',
    [string] $SourceClusterName = 'cs554-postgres',
    [string] $ObjectStoreName = 'cs554-s3-store',
    [string] $ImageName = 'ghcr.io/cloudnative-pg/postgresql:16.10-system-trixie'
)

$ErrorActionPreference = 'Stop'
if (kubectl get cluster $RestoreClusterName -n $Namespace 2>$null) {
    throw "Restore cluster $RestoreClusterName already exists. Delete it before retrying."
}

$restoreYaml = @"
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: $RestoreClusterName
  namespace: $Namespace
  labels:
    app.kubernetes.io/part-of: cs554-healthcare-platform
    app.kubernetes.io/component: phase5-pitr-restore
spec:
  instances: 1
  imageName: $ImageName
  bootstrap:
    recovery:
      source: source
      recoveryTarget:
        targetTime: $TargetTime
  externalClusters:
    - name: source
      plugin:
        name: barman-cloud.cloudnative-pg.io
        parameters:
          barmanObjectName: $ObjectStoreName
          serverName: $SourceClusterName
  storage:
    size: 10Gi
"@

$restoreFile = Join-Path $env:TEMP 'cs554-pitr-restore.yaml'
Set-Content -LiteralPath $restoreFile -Value $restoreYaml -Encoding utf8
kubectl apply -f $restoreFile
Remove-Item -LiteralPath $restoreFile -Force
Write-Host "PITR restore cluster requested: $RestoreClusterName"
Write-Host "Target time: $TargetTime"
