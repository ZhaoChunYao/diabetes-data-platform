# Phase 6 AWS EKS Acceptance Evidence

Captured: 2026-10-05 (America/New_York)

This report records the final verified AWS deployment. It contains resource
identifiers and operational results only; it does not contain AWS keys,
passwords, login caches, or a second copy of the database.

## Final result (archived pre-cleanup state)

Phase 6 was verified running successfully in AWS before cleanup. The following
is the captured deployment state, not a statement that these resources still
exist:

- EKS cluster: `cs554-phase6`
- Region: `us-east-2`
- EKS status: `ACTIVE`
- Kubernetes version: `1.34`
- Worker nodes: 2 x `t3.medium`, both `Ready`
- PostgreSQL: CloudNativePG 1.30.0, 2 instances, both `Ready`
- PostgreSQL primary: `cs554-postgres-eks-1`
- PostgreSQL replica: `cs554-postgres-eks-2`
- Storage: two encrypted 10Gi gp3 EBS volumes
- Flask: 1 replica, Pod `1/1 Running`
- ECR image digest: `sha256:07e5856d766ce389ccb5bf7cd0be70dff301afe44e4640b7b18a2d9b737b087e`
- S3 source: `s3://<backup-bucket>/cs554/phase5`
- PITR target: `2026-10-02T13:23:57Z`

## Application verification

The running Flask container returned:

```json
{"backend":"postgres","database":"connected","status":"healthy"}
```

The representative groups API returned four groups with data:

```json
{"groups":[
  {"count":372,"id":"healthy","name":"Healthy"},
  {"count":323,"id":"oral_medication_and_or_non_insulin_injectable_medication_controlled","name":"Oral Medication And Or Non Insulin Injectable Medication Controlled"},
  {"count":242,"id":"pre_diabetes_lifestyle_controlled","name":"Pre Diabetes Lifestyle Controlled"},
  {"count":130,"id":"insulin_dependent","name":"Insulin Dependent"}
]}
```

These requests were executed inside the running Flask Pod, so they verify the
actual cloud Deployment and its PostgreSQL connection rather than only a local
browser process.

## Browser smoke-test status

The cloud UI was opened through `kubectl port-forward` at
`http://localhost:5004`.

- Home page: displayed successfully.
- Feature 1: displayed 1,067 participants, 4 study groups, average age 62.2,
  and its charts. The first load took over one minute; this is recorded as a
  performance characteristic of the cloud deployment.
- Feature 2: displayed a glucose-by-study-group chart after selecting
  `Glucose (mg/dL)`.
- Feature 3: displayed a 10-day CGM trend chart with participant count, mean
  glucose, and time-in-range.
- Feature 4: the initial cloud UI request returned HTTP 500 because PostgreSQL
  rejected `SELECT DISTINCT ... ORDER BY expressions must appear in select
  list`. After the corrected image rollout, the same API returned HTTP 200 with
  raw participant activity and CGM timeseries data.
- Feature 5: the initial cloud UI request returned HTTP 500 because psycopg read
  the literal `%` in `HbA1c (%)` as a placeholder. After the corrected image
  rollout, the same API returned HTTP 200 with ECG and HbA1c records.

The final API verification was run by
`aws/rollout-and-verify-phase6.ps1` on 2026-10-05. Its captured output is in
`aws/evidence/phase6-final-verification-20261005-184958.txt`. The full
five-feature cloud API acceptance now passes. The separate browser smoke test
screenshots remain qualitative UI evidence; the API response evidence is the
authoritative functional check.

## PostgreSQL and PITR verification

The CloudNativePG status reported:

- `Cluster is in healthy state`
- `instances: 2`
- `readyInstances: 2`
- `currentPrimary: cs554-postgres-eks-1`
- `cs554-postgres-eks-2` on timeline 3 as the non-primary instance
- `Continuous archiving is working`
- Barman Cloud plugin version `0.15.0`
- both PVCs healthy and bound

The recovery log was captured during the successful restore. Key lines were:

```text
Restore through plugin detected, proceeding...
starting point-in-time recovery to 2026-10-02 13:23:57+00
restored log file 00000002000000000000009E from archive
restored log file 00000002000000000000009F from archive
restored log file 0000000200000000000000A0 from archive
restored log file 0000000200000000000000A1 from archive
restored log file 0000000200000000000000A2 from archive
consistent recovery state reached at 0/A0000000
recovery stopping before commit of transaction 981
archive recovery complete
restore command execution completed without errors
```

The completed recovery Job is no longer present in the namespace, but the
successful output above was captured while it ran. The current CloudNativePG
conditions independently confirm that bootstrap and continuous archiving are
healthy.

## S3 backup inventory

The verified S3 location contained one physical base backup and WAL files. The
base backup was:

```text
cs554/phase5/cs554-postgres/base/20261002T010010/backup.info  1,451 bytes
cs554/phase5/cs554-postgres/base/20261002T010010/data.tar     5,487,441,920 bytes
```

The WAL inventory included segments `00000002000000000000009D` through
`0000000200000000000000A6`, stored as compressed `.gz` objects. The restore
used the base backup plus WAL and stopped at the recorded target time.

## AWS and Kubernetes resources (archived pre-cleanup state)

```text
EKS addons: aws-ebs-csi-driver, coredns, kube-proxy, vpc-cni
Nodegroup: phase6-workers
Nodegroup status: ACTIVE
Node type: t3.medium
Desired/min/max: 2/2/2
StorageClass: cs554-gp3
Provisioner: ebs.csi.aws.com
Volume type: gp3
Encryption: true
Binding: WaitForFirstConsumer
```

The PostgreSQL ServiceAccount was annotated with:

```text
arn:aws:iam::<account-id>:role/cs554-phase6-postgres-s3
```

That role had the attached policy `cs554-barman-s3-policy`. The ObjectStore
used `s3Credentials.inheritFromIAMRole: true`; no access key was stored in
Kubernetes.

## Access without a public load balancer (historical procedure)

The Flask Service is intentionally `ClusterIP` to avoid exposing a public
endpoint and incurring a load-balancer cost. Use:

```powershell
kubectl port-forward -n cs554 service/cs554-app 5004:5001
```

Then open `http://localhost:5004`. The local port can be changed if `5001` is
already occupied by Docker or another port-forward.

## Cleanup status

Cleanup completed after the evidence was captured on 2026-10-05. The following
temporary runtime resources were deleted:

- Kubernetes namespace `cs554`
- EKS cluster `cs554-phase6`
- Managed nodegroup `phase6-workers` and its worker instances
- EKS control-plane add-ons, OIDC provider, and the EKS-specific PostgreSQL
  service-account IAM role
- PostgreSQL Pods, PVCs, and their cloud storage associated with the deleted
  namespace

The following project artifacts were intentionally retained:

- S3 backup bucket `<backup-bucket>` and its backup/WAL objects
- ECR repository and image `cs554-app:phase6`
- The IAM user and S3 policy used for backup access
- This report, the recovery summary, and the reviewed screenshots under
  `aws/evidence/screenshots/`

Therefore, this report is an archival record of a successful deployment and
restore test; the AWS runtime is no longer running and is not available for
interactive inspection.
