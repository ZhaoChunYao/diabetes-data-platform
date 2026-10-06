$ErrorActionPreference = 'Stop'

Write-Host '--- Nodes ---'
kubectl get nodes -o wide
Write-Host '--- CloudNativePG cluster ---'
kubectl get cluster -n cs554 cs554-postgres
Write-Host '--- PostgreSQL pods ---'
kubectl get pods -n cs554 -l cnpg.io/cluster=cs554-postgres -L role -o wide
Write-Host '--- Persistent volumes ---'
kubectl get pvc -n cs554
Write-Host '--- Services ---'
kubectl get svc -n cs554
Write-Host '--- Flask deployment ---'
kubectl get deployment,pod -n cs554 -l app.kubernetes.io/name=cs554-app

$health = Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:30003/health'
Write-Host '--- Flask /health ---'
$health.Content

Write-Host '--- Representative API check ---'
(Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:30003/api/groups').Content
