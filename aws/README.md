# Phase 6 - AWS EKS deployment

Phase 6 moves the tested application to AWS EKS. It is a deployment
portability exercise, not a second rewrite of the application or database.

## Required result

- EKS with two small managed worker nodes
- ECR image for Flask
- CloudNativePG and Barman Cloud plugin
- Two PostgreSQL instances with 10Gi EBS-backed storage each
- Recovery from the verified S3 base backup
- Flask connected to the recovered PostgreSQL service
- S3 access through an EKS IAM role for service accounts (IRSA), not an access
  key CSV stored in EKS

The IRSA design follows the Barman Cloud Plugin's documented EKS method. The
ObjectStore explicitly sets `s3Credentials.inheritFromIAMRole: true` and does
not contain static keys; the PostgreSQL service account receives the IAM role
annotation.

## Files

- `phase6-eksctl.yaml`: EKS, two workers, OIDC, IAM service account, and EBS CSI.
- `preflight-phase6.ps1`: read-only tool/AWS/disk checks.
- `build-push-ecr-v2.ps1`: creates ECR, builds the existing image, and pushes it.
- `deploy-phase6.ps1`: creates the namespace, S3 ObjectStore, recovered database,
  and Flask deployment. Temporary rendered YAML is removed afterward.
- `verify-phase6.ps1`: checks nodes, PostgreSQL, PVCs, and Flask resources.
- `cleanup-phase6.ps1`: removes the temporary namespace and optionally EKS.

## Run order

Run from this directory after authenticating an AWS principal that can create
EKS, ECR, IAM service-account roles, and EBS resources:

```powershell
.\preflight-phase6.ps1
eksctl create cluster -f .\phase6-eksctl.yaml
.\..\kubernetes\install-cnpg.ps1
.\..\kubernetes\install-barman-cloud.ps1
.\build-push-ecr-v2.ps1
```

Then deploy using the role created by eksctl, the verified Phase 5 PITR time,
and the ECR image printed by the push script:

```powershell
.\deploy-phase6.ps1 `
  -PostgresRoleArn 'arn:aws:iam::<account-id>:role/cs554-phase6-postgres-s3' `
  -TargetTime '2026-10-02T13:23:57Z' `
  -Bucket '<backup-bucket>' `
  -AppImage '<account-id>.dkr.ecr.us-east-2.amazonaws.com/cs554-app:phase6'
.\verify-phase6.ps1
```

After physical recovery, PostgreSQL restores the original database roles and
their password hashes. The deployment script therefore synchronizes the
recovered `app` role with the Kubernetes Secret before starting Flask. Use
`-DbPassword` if the application password is not `app_password`.

The app Service is `ClusterIP` to avoid a paid public load balancer. Use
`kubectl port-forward -n cs554 service/cs554-app 5001:5001` for the smoke test.

## Roll out a new application image and collect evidence

After pushing a new ECR image, use the single script below. It restarts only
the Flask Deployment; it does not recreate or delete the EKS cluster,
PostgreSQL cluster, PVCs, or S3 backup. It tests `/health`, `/api/groups`,
Feature 4, and Feature 5, and writes the captured output under `evidence/`.

```powershell
.\rollout-and-verify-phase6.ps1 `
  -Image '<account-id>.dkr.ecr.us-east-2.amazonaws.com/cs554-app:phase6'
```

To keep temporary local browser access open after the tests finish:

```powershell
.\rollout-and-verify-phase6.ps1 `
  -Image '<account-id>.dkr.ecr.us-east-2.amazonaws.com/cs554-app:phase6' `
  -KeepPortForward
```

The default browser address is `http://127.0.0.1:5004/`.

## Acceptance criteria

1. EKS nodes are Ready.
2. CloudNativePG has two healthy PostgreSQL instances.
3. Both PostgreSQL PVCs use EBS-backed storage.
4. The database recovered from the existing S3 backup.
5. Flask `/health` reports PostgreSQL connected.
6. A representative API returns data.

Failover and PITR were already executed locally against the same CloudNativePG
and S3 workflow in Phases 4 and 5. Repeating both in EKS is optional if budget
and time allow.

## Cost and cleanup

The EKS control plane, two EC2 workers, their root volumes, and two 10Gi EBS
database volumes are billable. Do not leave the lab running after evidence is
collected. Review resources, then run:

```powershell
.\cleanup-phase6.ps1 -DeleteEksCluster
```

Keep the local manifests and S3 backup; remove only temporary compute and
storage resources.
