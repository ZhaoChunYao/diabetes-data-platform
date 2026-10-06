param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^arn:aws:iam::\d{12}:role/.+$')]
    [string] $PostgresRoleArn,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}T.*(Z|[+-]\d{2}:\d{2})$')]
    [string] $TargetTime,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com/.+$')]
    [string] $AppImage,
    [string] $Namespace = 'cs554',
    [string] $Region = 'us-east-2',
    [Parameter(Mandatory = $true)] [string] $Bucket,
    [string] $SourcePrefix = 'cs554/phase5',
    [string] $SourceServerName = 'cs554-postgres',
    [string] $DbPassword = 'app_password'
)

$ErrorActionPreference = 'Stop'
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f - | Out-Null
kubectl create secret generic cs554-db-credentials -n $Namespace `
    --from-literal=username=app --from-literal=password=app_password `
    --dry-run=client -o yaml | kubectl apply -f - | Out-Null

$objectStoreYaml = @"
apiVersion: barmancloud.cnpg.io/v1
kind: ObjectStore
metadata:
  name: cs554-s3-restore
  namespace: $Namespace
spec:
  configuration:
    destinationPath: s3://$Bucket/$SourcePrefix
    s3Credentials:
      inheritFromIAMRole: true
  instanceSidecarConfiguration:
    env:
      - name: AWS_REGION
        value: $Region
      - name: AWS_DEFAULT_REGION
        value: $Region
"@

$clusterYaml = @"
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: cs554-postgres-eks
  namespace: $Namespace
  labels:
    app.kubernetes.io/part-of: cs554-healthcare-platform
    app.kubernetes.io/component: phase6-eks-database
spec:
  instances: 2
  imageName: ghcr.io/cloudnative-pg/postgresql:16.10-system-trixie
  serviceAccountTemplate:
    metadata:
      annotations:
        eks.amazonaws.com/role-arn: $PostgresRoleArn
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
          barmanObjectName: cs554-s3-restore
          serverName: $SourceServerName
  storage:
    size: 10Gi
"@

$appYaml = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cs554-app
  namespace: $Namespace
  labels:
    app.kubernetes.io/name: cs554-app
    app.kubernetes.io/part-of: cs554-healthcare-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: cs554-app
  template:
    metadata:
      labels:
        app.kubernetes.io/name: cs554-app
        app.kubernetes.io/part-of: cs554-healthcare-platform
    spec:
      containers:
        - name: app
          image: $AppImage
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 5001
          env:
            - name: DB_DRIVER
              value: postgres
            - name: DB_HOST
              value: cs554-postgres-eks-rw
            - name: DB_PORT
              value: "5432"
            - name: DB_NAME
              value: project_554
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: cs554-db-credentials
                  key: username
            - name: DB_PASS
              valueFrom:
                secretKeyRef:
                  name: cs554-db-credentials
                  key: password
            - name: PORT
              value: "5001"
          readinessProbe:
            httpGet:
              path: /health
              port: http
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 12
---
apiVersion: v1
kind: Service
metadata:
  name: cs554-app
  namespace: $Namespace
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: cs554-app
  ports:
    - name: http
      port: 5001
      targetPort: http
"@

$tempRoot = Join-Path $env:TEMP 'cs554-phase6'
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$objectStoreFile = Join-Path $tempRoot 'objectstore.yaml'
$clusterFile = Join-Path $tempRoot 'cluster.yaml'
$appFile = Join-Path $tempRoot 'app.yaml'
Set-Content -LiteralPath $objectStoreFile -Value $objectStoreYaml -Encoding utf8
Set-Content -LiteralPath $clusterFile -Value $clusterYaml -Encoding utf8
Set-Content -LiteralPath $appFile -Value $appYaml -Encoding utf8

kubectl apply -f $objectStoreFile
kubectl apply -f $clusterFile
kubectl wait --for=condition=Ready cluster/cs554-postgres-eks -n $Namespace --timeout=45m

# A physical PostgreSQL recovery restores the database roles and their old
# password hashes. Align the recovered application role with the Kubernetes
# Secret created above before starting Flask.
$primaryPod = kubectl get cluster/cs554-postgres-eks -n $Namespace -o jsonpath='{.status.currentPrimary}'
if ([string]::IsNullOrWhiteSpace($primaryPod)) { throw 'Recovered PostgreSQL has no current primary.' }
kubectl exec -n $Namespace $primaryPod -c postgres -- psql -d postgres -v ON_ERROR_STOP=1 -c "ALTER ROLE app WITH PASSWORD '$DbPassword';"

kubectl apply -f $appFile
$rolloutOutput = kubectl rollout status deployment/cs554-app -n $Namespace --timeout=10m 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Flask deployment rollout failed: $($rolloutOutput -join [Environment]::NewLine)"
}
$rolloutOutput | Write-Host
Remove-Item -LiteralPath $tempRoot -Recurse -Force
Write-Host 'Phase 6 application and recovered PostgreSQL cluster are ready.'
Write-Host 'Use: kubectl port-forward -n cs554 service/cs554-app 5001:5001'
