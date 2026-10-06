$ErrorActionPreference = 'Stop'

$namespace = 'cs554'
$cluster = 'cs554-postgres'
$database = 'project_554'
$markerTable = 'phase4_failover_check'
$timeoutSeconds = 600

function KubeText([string[]]$Arguments) {
    $output = & kubectl @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "kubectl failed: $($output -join [Environment]::NewLine)" }
    ($output -join [Environment]::NewLine).Trim()
}

function PrimaryPod { KubeText @('get','cluster',$cluster,'-n',$namespace,'-o','jsonpath={.status.currentPrimary}') }

function Sql([string]$Pod, [string]$Statement) {
    # CNPG's local socket uses peer authentication. The container's local
    # postgres identity can authenticate as the postgres database user.
    KubeText @('exec','-n',$namespace,$Pod,'-c','postgres','--','psql','-U','postgres','-d',$database,'-v','ON_ERROR_STOP=1','-tA','-c',$Statement)
}

$null = KubeText @('get','cluster',$cluster,'-n',$namespace)
$oldPrimary = PrimaryPod
if ([string]::IsNullOrWhiteSpace($oldPrimary)) { throw 'No current primary. Run .\verify.ps1 first.' }

$marker = "phase4-$([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss'))"
$setup = "CREATE TABLE IF NOT EXISTS $markerTable (id integer PRIMARY KEY, marker text NOT NULL, written_at timestamptz NOT NULL); INSERT INTO $markerTable VALUES (1, '$marker', now()) ON CONFLICT (id) DO UPDATE SET marker = EXCLUDED.marker, written_at = EXCLUDED.written_at;"
Write-Host "Writing marker to $oldPrimary..."
if ((Sql $oldPrimary $setup).Trim() -ne '') { }
if ((Sql $oldPrimary "SELECT marker FROM $markerTable WHERE id=1;").Trim() -ne $marker) { throw 'Marker write/read failed.' }

Write-Host "Deleting primary $oldPrimary..."
$timer = [Diagnostics.Stopwatch]::StartNew()
KubeText @('delete','pod',$oldPrimary,'-n',$namespace,'--wait=false') | Out-Host
$newPrimary = ''
for ($i=0; $i -lt ($timeoutSeconds / 5); $i++) {
    $candidate = PrimaryPod
    if ($candidate -and $candidate -ne $oldPrimary) {
        $phase = KubeText @('get','pod',$candidate,'-n',$namespace,'-o','jsonpath={.status.phase}')
        $null = & kubectl wait --for=condition=Ready "pod/$candidate" -n $namespace --timeout=5s 2>$null
        $ready = ($LASTEXITCODE -eq 0)
        if ($phase -eq 'Running' -and $ready) { $newPrimary = $candidate; break }
    }
    Start-Sleep -Seconds 5
}
$timer.Stop()
if (-not $newPrimary) { throw "No new primary after $timeoutSeconds seconds. Run kubectl describe cluster $cluster -n $namespace" }

$survived = (Sql $newPrimary "SELECT marker FROM $markerTable WHERE id=1;").Trim()
if ($survived -ne $marker) { throw "Marker did not survive promotion. Expected $marker, got $survived" }
$health = Invoke-RestMethod 'http://localhost:30003/health'
if ($health.status -ne 'healthy' -or $health.backend -ne 'postgres') { throw "Flask is not healthy: $($health | ConvertTo-Json -Compress)" }
Invoke-RestMethod 'http://localhost:30003/api/groups' | Out-Null
Sql $newPrimary "DROP TABLE IF EXISTS $markerTable;" | Out-Null

Write-Host 'Phase 4 failover test passed.' -ForegroundColor Green
Write-Host "Old primary: $oldPrimary"
Write-Host "Promoted primary: $newPrimary"
Write-Host "Recovery time: $([math]::Round($timer.Elapsed.TotalSeconds,1)) seconds"
Write-Host "Marker survived: $marker"
