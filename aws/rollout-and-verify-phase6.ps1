param(
    [string] $Namespace = 'cs554',
    [string] $DeploymentName = 'cs554-app',
    [string] $ContainerName = 'app',
    [Parameter(Mandatory = $true)] [string] $Image,
    [int] $LocalPort = 5004,
    [switch] $KeepPortForward
)

$ErrorActionPreference = 'Stop'

$evidenceDirectory = Join-Path $PSScriptRoot 'evidence'
New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$evidenceFile = Join-Path $evidenceDirectory "phase6-final-verification-$stamp.txt"
$portForward = $null
$portForwardOut = Join-Path $env:TEMP "cs554-port-forward-$stamp.out"
$portForwardErr = Join-Path $env:TEMP "cs554-port-forward-$stamp.err"

function Write-Evidence([string] $Text) {
    $Text | Tee-Object -FilePath $evidenceFile -Append
}

function Invoke-Kubectl([string[]] $Arguments) {
    $output = & kubectl @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "kubectl failed: $($output -join [Environment]::NewLine)"
    }
    $output
}

function Invoke-HttpJson([string] $Url) {
    $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 60
    if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
        throw "HTTP $($response.StatusCode) from $Url"
    }
    $response.Content
}

try {
    Write-Evidence "Phase 6 rollout and verification"
    Write-Evidence "Started: $(Get-Date -Format o)"
    Write-Evidence "Namespace: $Namespace"
    Write-Evidence "Image: $Image"
    Write-Evidence ''

    Write-Evidence '--- Kubernetes context ---'
    Write-Evidence ((Invoke-Kubectl @('config', 'current-context')) -join [Environment]::NewLine)
    Write-Evidence '--- EKS nodes ---'
    Write-Evidence ((Invoke-Kubectl @('get', 'nodes', '-o', 'wide')) -join [Environment]::NewLine)

    Write-Evidence '--- Updating Flask image and restarting only the application deployment ---'
    Invoke-Kubectl @('set', 'image', "deployment/$DeploymentName", "$ContainerName=$Image", '-n', $Namespace) | Out-Null
    Invoke-Kubectl @('rollout', 'restart', "deployment/$DeploymentName", '-n', $Namespace) | Out-Null
    Write-Evidence ((Invoke-Kubectl @('rollout', 'status', "deployment/$DeploymentName", '-n', $Namespace, '--timeout=5m')) -join [Environment]::NewLine)

    Write-Evidence '--- Application pod ---'
    Write-Evidence ((Invoke-Kubectl @('get', 'pods', '-n', $Namespace, '-l', 'app.kubernetes.io/name=cs554-app', '-o', 'wide')) -join [Environment]::NewLine)
    $podJson = (Invoke-Kubectl @('get', 'pods', '-n', $Namespace, '-l', 'app.kubernetes.io/name=cs554-app', '-o', 'json')) -join [Environment]::NewLine
    $podList = $podJson | ConvertFrom-Json
    $runningPod = @($podList.items | Where-Object {
        $_.status.phase -eq 'Running' -and
        $_.status.containerStatuses -and
        $_.status.containerStatuses[0].ready -eq $true
    } | Select-Object -First 1)
    if ($runningPod.Count -ne 1) { throw 'No Running and Ready Flask pod was found.' }
    Write-Evidence "Selected running pod: $($runningPod[0].metadata.name)"
    Write-Evidence "Running image ID: $($runningPod[0].status.containerStatuses[0].imageID)"

    Write-Evidence '--- PostgreSQL cluster ---'
    Write-Evidence ((Invoke-Kubectl @('get', 'cluster', 'cs554-postgres-eks', '-n', $Namespace, '-o', 'wide')) -join [Environment]::NewLine)
    Write-Evidence ((Invoke-Kubectl @('get', 'pods', '-n', $Namespace, '-l', 'cnpg.io/cluster=cs554-postgres-eks', '-L', 'role', '-o', 'wide')) -join [Environment]::NewLine)
    Write-Evidence ((Invoke-Kubectl @('get', 'pvc', '-n', $Namespace, '-l', 'cnpg.io/cluster=cs554-postgres-eks')) -join [Environment]::NewLine)

    Write-Evidence '--- Starting temporary local port-forward ---'
    $portForward = Start-Process -FilePath 'kubectl.exe' `
        -ArgumentList @('port-forward', '-n', $Namespace, 'service/cs554-app', "$LocalPort`:`5001") `
        -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput $portForwardOut `
        -RedirectStandardError $portForwardErr

    $forwardReady = $false
    for ($attempt = 1; $attempt -le 30; $attempt++) {
        if (Test-NetConnection -ComputerName 127.0.0.1 -Port $LocalPort -InformationLevel Quiet) {
            $forwardReady = $true
            break
        }
        if ($portForward.HasExited) {
            throw "port-forward exited early: $((Get-Content $portForwardErr -ErrorAction SilentlyContinue) -join ' ')"
        }
        Start-Sleep -Seconds 1
    }
    if (-not $forwardReady) { throw "Timed out waiting for localhost:$LocalPort" }

    $baseUrl = "http://127.0.0.1:$LocalPort"
    Write-Evidence '--- Flask health ---'
    Write-Evidence (Invoke-HttpJson "$baseUrl/health")
    Write-Evidence '--- Groups API ---'
    Write-Evidence (Invoke-HttpJson "$baseUrl/api/groups")
    Write-Evidence '--- Feature 4 API ---'
    Write-Evidence (Invoke-HttpJson "$baseUrl/api/feature4/single-participant?groups=healthy&activity_metric=steps&day_start=5&day_end=5")
    Write-Evidence '--- Feature 5 API ---'
    Write-Evidence (Invoke-HttpJson "$baseUrl/api/feature5/ecg_hba1c")

    Write-Evidence ''
    Write-Evidence "Verification completed: $(Get-Date -Format o)"
    Write-Evidence "Evidence file: $evidenceFile"
    Write-Host "Phase 6 rollout and API verification passed." -ForegroundColor Green
    Write-Host "Evidence: $evidenceFile"
    Write-Host "Browser URL: $baseUrl/"
    if ($KeepPortForward) {
        Write-Host "Port-forward is still running because -KeepPortForward was supplied. PID: $($portForward.Id)"
        $portForward = $null
    }
}
finally {
    if ($portForward -and -not $portForward.HasExited) {
        Stop-Process -Id $portForward.Id -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $portForwardOut, $portForwardErr -Force -ErrorAction SilentlyContinue
}
