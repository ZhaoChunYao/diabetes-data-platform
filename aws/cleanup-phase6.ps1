param(
    [string] $Namespace = 'cs554',
    [string] $ClusterName = 'cs554-phase6',
    [switch] $DeleteEksCluster
)

$ErrorActionPreference = 'Stop'
kubectl delete namespace $Namespace --ignore-not-found --wait=true
if ($DeleteEksCluster) {
    eksctl delete cluster --name $ClusterName --region us-east-2 --wait
}
else {
    Write-Host 'EKS cluster was kept. Pass -DeleteEksCluster after reviewing AWS resources.'
}
