# Diabetes Data Platform

This repository documents a four-phase modernization of a Flask healthcare
analytics application:

1. `original/` — the corrected MySQL reference application.
2. `docker/` — Dockerized MySQL and PostgreSQL versions, including the full
   PostgreSQL migration path.
3. `kubernetes/` — local Kubernetes and CloudNativePG deployment, persistent
   storage, and a real primary-failure promotion test.
4. `aws/` — EKS, ECR, encrypted EBS storage, S3-backed Barman Cloud recovery,
   and deployment runbooks.

Phases 1–6 were executed and verified. The temporary EKS runtime was deleted
after evidence collection to avoid ongoing charges. The S3 backup, ECR image,
deployment manifests, runbooks, and local acceptance evidence were retained.

## Public-repository boundary

This public repository contains application code, schemas, deployment
templates, scripts, and documentation. It intentionally does not contain:

- the authorized course SQL dump;
- the AI-READI source dataset or processed patient-level data;
- AWS access-key files, login caches, passwords, or `.env` files;
- raw cloud API payloads. The manually reviewed screenshots are included as
  qualitative UI evidence under `aws/evidence/screenshots/`.

The public Docker quick start uses the small synthetic PostgreSQL fixture:

```powershell
cd docker
docker compose -f docker-compose.postgres.yml up --build -d
```

Open `http://localhost:5002/`. The full-data workflow requires the separately
authorized SQL dump and is documented in `docker/PROJECT_GUIDE.md`.

## Cloud deployment

The AWS files use placeholders for account-specific values. Substitute the
account ID, ECR image, backup bucket, and IAM role in your own environment
before running the scripts. The EKS runtime is intentionally not left running
by default.

See:

- [`docker/PROJECT_GUIDE.md`](docker/PROJECT_GUIDE.md)
- [`kubernetes/README.md`](kubernetes/README.md)
- [`aws/README.md`](aws/README.md)
- [`aws/evidence/PHASE6_ACCEPTANCE_REPORT.md`](aws/evidence/PHASE6_ACCEPTANCE_REPORT.md)

This is a research-data exploration application, not a medical diagnosis or
treatment system.
