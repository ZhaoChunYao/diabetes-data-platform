# Phase 3 - Local Kubernetes and CloudNativePG

This directory contains the Phase 3 deployment for the verified full PostgreSQL
database. It is intentionally separate from `original/` and `docker/`:

- `original/` is the preserved pre-modernization project.
- `docker/` is the verified Compose implementation from Phases 1 and 2.
- `kubernetes/` is the local Kubernetes implementation for Phase 3.
- `aws/` is reserved for the later cloud phase.

## What this phase creates

For this resource-constrained local profile, CloudNativePG manages two PostgreSQL
instances:

```text
cs554-postgres-1  primary
cs554-postgres-2  replica
```

The Flask Deployment connects to the CloudNativePG-managed read-write service:

```text
cs554-postgres-rw.cs554.svc.cluster.local:5432
```

The application is exposed locally at `http://localhost:30003`.

The existing full PostgreSQL Compose database is used only as the import source.
CloudNativePG imports `project_554` once during first bootstrap; replication then
copies the imported data from the primary to the one replica. The Compose source
must remain healthy until the import finishes.

## Prerequisites

1. Enable Docker Desktop Kubernetes.
2. Select the `docker-desktop` context.
3. Confirm that `kubectl get nodes` shows a `Ready` node.
4. Give Docker Desktop at least 4 CPUs and 8 GB memory for this local lab.
5. Ensure the Docker Desktop virtual disk has enough room for two PostgreSQL
   data volumes. The manifest requests 10Gi per instance.

Run these checks from this directory:

```powershell
kubectl config use-context docker-desktop
kubectl get nodes
```

## First deployment

Run PowerShell as the same user that can run Docker Desktop commands. The first
step installs the CloudNativePG operator from the pinned official 1.30.0 release:

```powershell
.\install-cnpg.ps1
```

Then deploy the source database, build the local application image, import the
complete database, and start Flask:

```powershell
.\deploy.ps1
```

The default local database password is `app_password`, matching the Compose
baseline. To use another password without putting it in a manifest:

```powershell
$env:CS554_DB_PASSWORD = 'your-local-password'
.\deploy.ps1
```

The import can take several minutes. The deployment script waits for the source
database, the CloudNativePG cluster, and the Flask rollout rather than assuming
that a process is ready merely because its container exists.

## Acceptance checks

```powershell
.\verify.ps1
```

The local resource-constrained profile is complete when:

- the CloudNativePG Cluster reports `2` instances and `2` ready instances;
- one PostgreSQL pod has role `primary` and one has role `replica`;
- two PVCs exist for the cluster;
- Flask reports `"backend":"postgres"` from `/health`;
- `/api/groups` returns data;
- the feature pages work at `http://localhost:30003`;
- the Compose source can be stopped after the import, while the Kubernetes
  application continues to use the CloudNativePG cluster.

The actual primary deletion and automatic promotion test is the next Phase 4 step.
The cloud profile can scale this same Cluster resource to three instances across
separate nodes or availability zones; three local instances on one Docker Desktop
node would not prove that level of availability.

## Phase 4 - Primary failure and automatic promotion

After the reduced two-instance profile passes `verify.ps1`, run:

```powershell
.\failover.ps1
```

The script writes one temporary marker row, identifies the current primary,
deletes only that PostgreSQL pod, waits for CloudNativePG to promote the replica,
checks that the marker survived, and calls Flask `/health` and `/api/groups`.
It removes the temporary marker table after a successful check. It does not delete
the Compose source volume or the PostgreSQL PVCs.

This proves local instance-level failover. It does not prove an AWS availability
zone failure, because Docker Desktop runs the local instances on one node.

## Important storage note

Changing `instances` from 3 to 2 and `storage.size` from `20Gi` to `10Gi` does not
shrink existing PostgreSQL PVCs in place. For this local lab profile, the old
Kubernetes cluster/PVCs must be removed and `deploy.ps1` run again. CloudNativePG
will then import the source database into two new 10Gi volumes. The Docker Compose
PostgreSQL source volume is kept until the reduced Kubernetes deployment is
verified.

## After a successful import

Once `verify.ps1` passes, the standalone Compose source is no longer needed for
the running Kubernetes application. It can be stopped without deleting its
volume:

```powershell
Push-Location ..\docker
docker compose -f docker-compose.postgres-full.yml stop db
Pop-Location
```

Do not delete the Compose volume until the Kubernetes copy has been independently
verified. The source volume remains a rollback/reference copy for this phase.

### Recreate the reduced local profile

Run this only when the current Kubernetes copy can be discarded. It removes the
Kubernetes copy of the database, not the Docker Compose source volume:

```powershell
kubectl config use-context docker-desktop
kubectl delete cluster cs554-postgres -n cs554 --wait=true --ignore-not-found
kubectl delete pvc cs554-postgres-1 cs554-postgres-2 cs554-postgres-3 -n cs554 --wait=true --ignore-not-found
.\deploy.ps1
.\verify.ps1
```

The deployment script starts the verified PostgreSQL Compose source, imports the
database again, and creates two new 10Gi PVCs. Do not remove the Compose source
volume until verification succeeds.

## Troubleshooting

Inspect the operator, cluster, and import messages with:

```powershell
kubectl get pods -n cnpg-system
kubectl get cluster -n cs554 cs554-postgres -o yaml
kubectl describe cluster -n cs554 cs554-postgres
kubectl get pods -n cs554 -o wide
```

If the import cannot reach `host.docker.internal:5434`, confirm that the full
PostgreSQL Compose source is healthy and that its port mapping is still `5434`.
Do not delete the cluster or PVCs as a first troubleshooting step; inspect the
CloudNativePG status and events first.

## Official references

- [CloudNativePG installation](https://cloudnative-pg.io/docs/current/installation_upgrade/)
- [CloudNativePG database import](https://cloudnative-pg.io/docs/current/database_import/)
- [CloudNativePG service management](https://cloudnative-pg.io/docs/current/service_management/)

## Phase 5 - AWS S3 backup and point-in-time recovery

Phase 5 uses the real AWS S3 service. It does not use `pg_dump`, MinIO, or a
second local backup volume. CloudNativePG's Barman Cloud Plugin writes physical
base backups and WAL archives to an S3 prefix. The local Docker Desktop cluster
is only the producer and recovery test environment.

The implementation uses these scripts:

- `install-barman-cloud.ps1` installs Barman Cloud Plugin `0.15.0`.
- `configure-s3-backup.ps1` creates the Kubernetes credential Secret, creates
  the S3 `ObjectStore`, and enables WAL archiving on `cs554-postgres`.
- `phase5-marker.ps1` creates controlled recovery markers without changing
  application tables.
- `create-s3-backup.ps1` requests an on-demand physical backup.
- `verify-phase5.ps1` summarizes the plugin, ObjectStore, backups, and pods.
- `restore-pitr.ps1` creates a one-instance temporary cluster restored to a
  specified UTC time.

The local test uses access keys in a Kubernetes Secret because Docker Desktop
does not provide EKS IRSA. Do not use the AWS root access key. Use a dedicated
least-privilege IAM principal restricted to the dedicated bucket/prefix. On
EKS, replace the Secret with an IAM role for the PostgreSQL service account.

The exact bucket/prefix policy is saved in `phase5-s3-iam-policy.json`. It
includes the multipart-upload permissions required by large physical backups;
WAL uploads can work even when those permissions are missing, so WAL success
alone is not sufficient evidence that base backups will work.

The scripts expect these values in the PowerShell session, but never put them
in the repository:

```powershell
$env:CS554_AWS_ACCESS_KEY_ID = '...'
$env:CS554_AWS_SECRET_ACCESS_KEY = '...'
```

After the Barman plugin is installed, configure the existing cluster:

```powershell
.\configure-s3-backup.ps1 -Bucket '<bucket-name>' -Region '<aws-region>'
```

Then perform the PITR experiment in this order:

```powershell
.\phase5-marker.ps1 -Action Initialize
.\create-s3-backup.ps1
kubectl get backup -n cs554 -w
.\phase5-marker.ps1 -Action AfterBaseBackup
.\phase5-marker.ps1 -Action InsertDeleteTarget
.\phase5-marker.ps1 -Action DeleteTarget
```

Record the timestamp printed by `InsertDeleteTarget`, then restore to a time
slightly after that insert and before `DeleteTarget`:

```powershell
.\restore-pitr.ps1 -TargetTime 'YYYY-MM-DDTHH:MM:SSZ'
```

The recovered cluster must contain `delete_target`. That row was inserted after
the base backup, so its presence proves WAL replay. The production cluster is
not overwritten. After validation, delete the temporary `cs554-pitr-restore`
Cluster and its PVC.

### Verified result (2026-10-02)

The S3 backup and PITR workflow was executed successfully:

- S3 base backup: `backup-20261002010010`, status `DONE`
- Physical backup object: approximately 5.49 GB, uncompressed
- WAL archiving: verified in the same S3 prefix
- PITR target: `2026-10-02T13:23:57Z`
- Temporary one-instance recovery cluster became healthy
- The recovered database contained `before_base_backup`,
  `after_base_backup`, and `delete_target`
- The production two-instance cluster remained healthy throughout
- The temporary recovery cluster and its PVC were deleted after validation

This proves that the S3 base backup plus WAL replay can recover the database to
a point after an insert and before the later deletion.
