# Diabetes Data Platform — Four-Phase Project

This repository presents the same application as four stages:

| Folder | Purpose | Current status |
|---|---|---|
| [`original/`](original/) | Corrected course version using MySQL | Runnable reference version |
| [`docker/`](docker/) | PostgreSQL and Docker deployment | Runnable Phase 2 version |
| [`kubernetes/`](kubernetes/) | Kubernetes deployment plan and future manifests | Reserved for Phase 3 |
| [`aws/`](aws/) | AWS/EKS deployment plan and future manifests | Reserved for Phase 4 |

The folders are intentionally visible instead of making the reader navigate Git tags. The tags may remain as historical backup points, but the four folders are the primary project organization.

## Quick start

For the public repository, use the small synthetic PostgreSQL demo:

```powershell
cd docker
docker compose -f docker-compose.postgres.yml up --build -d
```

Open `http://localhost:5002/`.

The demo data is synthetic and safe to publish. The real AI-READI data and the course SQL dump are not included. The full-data MySQL workflow expects the authorized dump at the repository root:

```text
sql_dump/project_554_complete.sql
```

That directory is ignored by Git. From `docker/`, start the full MySQL version with:

```powershell
docker compose -f docker-compose.yml up --build -d
```

## Data source and SQL dump provenance

The application is based on the [AI-READI Flagship Dataset](https://aireadi.org/). See the [official documentation](https://docs.aireadi.org/) and [dataset access portal](https://fairhub.io/datasets/1/access/login).

The SQL dump is not downloaded directly from that website. It is a logical export of a populated `project_554` MySQL database after project-specific cleaning, field mapping, table loading, and aggregate generation. The repository contains the schema and a partial loader as documentation, plus a small synthetic fixture for demonstration. A raw-data download alone cannot currently recreate the exact course dump without completing those missing ETL steps.

## Phase documentation

- [Original version guide](original/PROJECT_GUIDE.md)
- [Docker/PostgreSQL Phase 2 guide](docker/PROJECT_GUIDE.md)
- [Kubernetes phase notes](kubernetes/README.md)
- [AWS/EKS phase notes](aws/README.md)
