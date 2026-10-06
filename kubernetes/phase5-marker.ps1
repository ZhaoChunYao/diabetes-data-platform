param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Initialize', 'AfterBaseBackup', 'InsertDeleteTarget', 'DeleteTarget', 'Read')]
    [string] $Action,
    [string] $Namespace = 'cs554',
    [string] $ClusterName = 'cs554-postgres',
    [string] $Database = 'project_554'
)

$ErrorActionPreference = 'Stop'
$primary = kubectl get cluster $ClusterName -n $Namespace -o jsonpath='{.status.currentPrimary}'
if ([string]::IsNullOrWhiteSpace($primary)) {
    throw 'CloudNativePG has not reported a current primary.'
}

$sql = switch ($Action) {
    'Initialize' {
        @"
CREATE TABLE IF NOT EXISTS phase5_recovery_markers (
  marker_id text PRIMARY KEY,
  marker_time timestamptz NOT NULL DEFAULT clock_timestamp(),
  note text NOT NULL
);
INSERT INTO phase5_recovery_markers(marker_id, note)
VALUES ('before_base_backup', 'Present before the S3 base backup')
ON CONFLICT (marker_id) DO NOTHING;
SELECT marker_id, marker_time, note FROM phase5_recovery_markers ORDER BY marker_time;
"@
    }
    'AfterBaseBackup' {
        "INSERT INTO phase5_recovery_markers(marker_id, note) VALUES ('after_base_backup', 'Inserted after the S3 base backup'); SELECT marker_id, marker_time FROM phase5_recovery_markers WHERE marker_id = 'after_base_backup';"
    }
    'InsertDeleteTarget' {
        "INSERT INTO phase5_recovery_markers(marker_id, note) VALUES ('delete_target', 'This row should exist before the PITR target and be absent after deletion'); SELECT marker_id, marker_time FROM phase5_recovery_markers WHERE marker_id = 'delete_target';"
    }
    'DeleteTarget' {
        "DELETE FROM phase5_recovery_markers WHERE marker_id = 'delete_target'; SELECT clock_timestamp() AS deletion_time;"
    }
    'Read' {
        'SELECT marker_id, marker_time, note FROM phase5_recovery_markers ORDER BY marker_time;'
    }
}

Write-Host "Running $Action on primary $primary..."
kubectl exec -n $Namespace $primary -c postgres -- psql -U postgres -d $Database -v ON_ERROR_STOP=1 -c $sql
