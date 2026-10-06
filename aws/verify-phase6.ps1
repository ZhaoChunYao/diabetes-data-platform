param([string] $Namespace = 'cs554')

$ErrorActionPreference = 'Stop'
Write-Host '--- EKS nodes ---'
kubectl get nodes -o wide
Write-Host '--- CloudNativePG cluster ---'
kubectl get cluster -n $Namespace cs554-postgres-eks -o wide
Write-Host '--- PostgreSQL pods and PVCs ---'
kubectl get pods -n $Namespace -l cnpg.io/cluster=cs554-postgres-eks -L role -o wide
kubectl get pvc -n $Namespace -l cnpg.io/cluster=cs554-postgres-eks
Write-Host '--- Flask deployment ---'
kubectl get deployment,service -n $Namespace cs554-app
