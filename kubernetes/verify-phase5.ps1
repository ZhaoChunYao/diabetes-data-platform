$ErrorActionPreference = 'Stop'

Write-Host '--- CloudNativePG cluster ---'
kubectl get cluster -n cs554 cs554-postgres -o wide
Write-Host '--- Barman plugin and ObjectStore ---'
kubectl get pods -n cnpg-system | Select-String 'barman'
kubectl get objectstore -n cs554 cs554-s3-store -o wide
Write-Host '--- Backup resources ---'
kubectl get backup -n cs554 --sort-by=.metadata.creationTimestamp
Write-Host '--- PostgreSQL pods ---'
kubectl get pods -n cs554 -l cnpg.io/cluster=cs554-postgres -o wide
Write-Host 'If a backup failed: kubectl logs -n cs554 <primary-pod> -c plugin-barman-cloud --tail=100'
