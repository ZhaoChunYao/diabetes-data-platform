# Phase 6 Runbook and Lessons Learned

This document is the practical record for repeating the deployment on another
machine or AWS account. It records the failures that actually occurred during
this project and the corresponding fixes.

## Repeatable deployment order

1. Confirm the AWS region, account, EKS tool versions, Docker Desktop, and AWS
   login are available.
2. Create the EKS cluster and two managed `t3.medium` workers with `eksctl`.
3. Update kubeconfig and confirm both nodes are `Ready`.
4. Install or verify cert-manager, CloudNativePG, the Barman Cloud plugin, and
   the EBS CSI addon.
5. Create the encrypted `cs554-gp3` StorageClass before creating PostgreSQL
   PVCs.
6. Create the IRSA ServiceAccount and confirm its IAM role annotation.
7. Create the ObjectStore with both the S3 destination and
   `s3Credentials.inheritFromIAMRole: true`.
8. Create the two-instance CloudNativePG recovery Cluster with the verified
   PITR target time.
9. Wait for the primary and replica to become healthy.
10. Synchronize the recovered `app` PostgreSQL role password with the
    Kubernetes application Secret.
11. Build and push the Flask image to ECR from a PowerShell session that can
    access Docker Desktop.
12. Apply the Flask Deployment and Service.
13. Verify `/health`, one representative API, Pod status, Cluster status, and
    PVC status.
14. Use `kubectl port-forward` for private local access; do not create a public
    load balancer unless that is an explicit requirement.

## Failure records

### 1. Recovery reported “no credentials defined”

**Cause:** The ObjectStore had the S3 path and IRSA environment variables, but
the Barman Cloud plugin still required an explicit credentials mode.

**Fix:** Add:

```yaml
s3Credentials:
  inheritFromIAMRole: true
```

**Prevention:** Keep this field in both the checked-in manifest and the deploy
script. Do not put access keys in the ObjectStore or Kubernetes Secret.

### 2. PVC had no storage class and recovery could not provision storage

**Cause:** EKS did not have a matching default StorageClass for the desired
encrypted gp3 volume.

**Fix:** Create `cs554-gp3` using the EBS CSI provisioner before applying the
PostgreSQL Cluster.

**Prevention:** Verify `kubectl get storageclass cs554-gp3` before recovery.

### 3. Flask entered CrashLoopBackOff with password authentication failure

**Cause:** Physical PostgreSQL recovery restores database roles and their old
password hashes. The Kubernetes Secret used `app_password`, but the restored
`app` role had a different password.

**Fix:** After the recovered primary became Ready, run:

```sql
ALTER ROLE app WITH PASSWORD 'app_password';
```

The Phase 6 deploy script now performs this synchronization before starting
Flask.

**Prevention:** Do not assume a Kubernetes Secret changes an already-restored
PostgreSQL role. Treat role-password synchronization as part of physical
recovery.

### 4. ECR build worked only from the user's PowerShell

**Cause:** Docker Desktop's named pipe was not accessible to the Codex process,
although it was accessible in the user's PowerShell.

**Fix:** Use `build-push-ecr-v2.ps1`, which builds from the existing
`Dockerfile.postgres`, logs in to ECR, and pushes the tagged image. The final
image digest is recorded in the acceptance report.

**Prevention:** Keep Docker build/push as a user-session prerequisite unless
the automation environment is explicitly granted Docker access.

### 5. AWS login cache was inaccessible to the automation process

**Cause:** Windows ACLs allowed the interactive user but denied the child
process used by the automation environment.

**Fix:** Use AWS CLI's supported `AWS_LOGIN_CACHE_DIRECTORY` setting with a
temporary cache copy. Delete the temporary copy after use. Never commit or
retain that copy in the project.

### 6. EKS and local Compose resources appeared under one Docker project

**Cause:** Compose project names were derived from the same directory/project
name, which made MySQL, PostgreSQL, and migration containers look like one
stack in Docker Desktop.

**Fix:** Use explicit project names and distinct compose files. The EKS phase
uses Kubernetes resources and is not a Docker Compose project.

### 7. Port-forward failed because local port 5001 was occupied

**Cause:** The local Docker app or an older port-forward already used port
`5001`.

**Fix:** Use another local port, for example:

```powershell
kubectl port-forward -n cs554 service/cs554-app 5004:5001
```

The right-hand port remains the Flask Service port inside Kubernetes.

### 8. `kubectl get cluster,pods,pvc` failed

**Cause:** `kubectl get` accepts one resource type per invocation in this form.

**Fix:** Query them separately:

```powershell
kubectl get cluster -n cs554
kubectl get pods -n cs554
kubectl get pvc -n cs554
```

### 9. Feature 4 failed after PostgreSQL migration

**Cause:** PostgreSQL rejects `SELECT DISTINCT` combined with an
`ORDER BY RANDOM()` expression that is not in the select list.

**Fix:** Select the participant columns, group by those columns, and then order
the grouped result randomly. The source fix is in
`docker/backend/server_unified.py`; rebuild the ECR image before claiming the
cloud Feature 4 smoke test passed.

### 10. Feature 5 failed after PostgreSQL migration

**Cause:** psycopg treats `%` as a parameter-format character. The SQL literal
`HbA1c (%)` therefore failed before PostgreSQL executed the query.

**Fix:** Use `HbA1c (%%)` in the PostgreSQL query string and keep the original
literal for MySQL. The source fix is in `docker/backend/server_unified.py`;
rebuild the ECR image before claiming the cloud Feature 5 smoke test passed.

## Safety rules for the next deployment

- Do not delete the S3 base backup or WALs before a restore has been verified.
- Do not delete the EKS cluster until screenshots, logs, image digest, and
  resource inventory have been saved.
- Do not upload access-key CSV files, AWS login caches, or database passwords
  into Git.
- Do not create a public LoadBalancer just to demonstrate the app; use
  port-forward unless public access is explicitly required.
- Record the exact PITR target time and ECR digest for every run.
- Keep failed-attempt summaries separate from the final acceptance state.
- Treat a page that loads as insufficient evidence; click its main action and
  record the returned chart or the exact HTTP error.

## Cleanup order when the owner authorizes it

1. Stop port-forward and confirm the user no longer needs the app.
2. Delete the Flask Deployment and Service.
3. Delete the PostgreSQL Cluster and confirm EBS PVC/volumes are gone.
4. Delete the `cs554` namespace if it is no longer needed.
5. Delete the EKS managed nodegroup.
6. Delete the EKS cluster.
7. Remove the ECR repository only if the image is no longer useful.
8. Remove the IRSA role/policy only after confirming no other workload uses it.
9. Keep the S3 backup until disaster-recovery evidence is no longer needed.
