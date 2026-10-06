param(
    [string] $Namespace = 'cs554',
    [string] $ClusterName = 'cs554-postgres',
    [string] $PluginName = 'barman-cloud.cloudnative-pg.io'
)

$ErrorActionPreference = 'Stop'
$backupYaml = @"
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  generateName: $ClusterName-s3-
  namespace: $Namespace
spec:
  cluster:
    name: $ClusterName
  method: plugin
  pluginConfiguration:
    name: $PluginName
"@

$backupFile = Join-Path $env:TEMP 'cs554-backup.yaml'
Set-Content -LiteralPath $backupFile -Value $backupYaml -Encoding utf8
kubectl create -f $backupFile
Remove-Item -LiteralPath $backupFile -Force

Write-Host 'Backup requested. Monitor it with: kubectl get backup -n cs554 -w'
