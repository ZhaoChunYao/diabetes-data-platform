# Diabetes Data Platform

An interactive Flask application for exploring de-identified type 2 diabetes research data. The project began as a CS554 course database application and was later adapted for reproducible Docker and PostgreSQL deployment.

## Data source

The original project is based on the AI-READI Flagship Dataset for Type 2 Diabetes:

- [AI-READI project website](https://aireadi.org/)
- [Official dataset documentation](https://docs.aireadi.org/)
- [Dataset access portal](https://fairhub.io/datasets/1/access/login)

The real dataset is not included in this repository. It may contain restricted research data and must be obtained directly from the official source under its access and license terms. Do not upload the real dataset, the course SQL dump, participant files, or database backups to GitHub.

## How the SQL dump relates to the original data

The file used by the full local deployment, `sql_dump/project_554_complete.sql`, is not a file downloaded directly from the AI-READI website. It is a MySQL logical export of an already populated `project_554` database.

The intended data pipeline is:

```text
AI-READI raw files
    -> project-specific cleaning and field mapping
    -> normalized project_554 tables
    -> indexes, keys, and daily summaries
    -> mysqldump export
```

The schema files in this repository describe the database target. The older [`loaders/master_loader.py`](loaders/master_loader.py) shows part of the intended loading approach, but it is not a complete raw-to-SQL reproduction pipeline: it expects a particular preprocessed directory layout, and several modalities and aggregate-table steps are incomplete. Therefore, downloading the official raw files alone does not currently recreate the exact SQL dump used by this application.

To reproduce the verified full-data runtime today, obtain an authorized copy of a compatible populated SQL dump separately. To rebuild the dump directly from the official raw files, the missing cleaning, mapping, aggregate-generation, and validation steps would need to be implemented first.

## Quick demo with synthetic data

The repository includes a tiny synthetic seed database. The records use `demo-*` identifiers and are not copied from real participants. This is the recommended way to evaluate the application from GitHub.

Start the representative PostgreSQL demo:

```powershell
docker compose -f docker-compose.postgres.yml up --build -d
```

Open:

- http://localhost:5002/
- http://localhost:5002/feature1.html
- http://localhost:5002/feature2.html
- http://localhost:5002/feature3.html
- http://localhost:5002/feature4.html
- http://localhost:5002/feature5.html

Check the backend:

```powershell
Invoke-WebRequest http://localhost:5002/health | Select-Object -ExpandProperty Content
Invoke-WebRequest http://localhost:5002/api/groups | Select-Object -ExpandProperty Content
```

The small PostgreSQL fixture is created by [`docker/postgres/init/001_schema_and_seed.sql`](docker/postgres/init/001_schema_and_seed.sql).

## Database schema

The repository's schema is organized into three layers:

- [`schema/01_metadata_tables.sql`](schema/01_metadata_tables.sql) - participants and metadata
- [`schema/02_daily_aggregates.sql`](schema/02_daily_aggregates.sql) - daily summaries
- [`schema/03_timeseries_tables.sql`](schema/03_timeseries_tables.sql) - minute-level readings
- [`DATABASE_DESIGN_REPORT.md`](DATABASE_DESIGN_REPORT.md) - relationships, indexes, and design rationale

The synthetic PostgreSQL fixture is a runnable, small version of these application tables. It is intended for demonstration, not for statistical conclusions about the real study.

## Full-data Docker and PostgreSQL migration

The complete local workflow is separate from the GitHub demo. It requires an authorized copy of the course-scale SQL database, which is intentionally excluded by `.gitignore`. This is a derived database artifact, not the official raw download.

1. Place the authorized dump at `sql_dump/project_554_complete.sql`.
2. Start the complete MySQL source database:

   ```powershell
   docker compose -f docker-compose.yml up -d db
   ```

3. Wait until MySQL reports `healthy`.
4. Start PostgreSQL and migrate the source database:

   ```powershell
   docker compose -f docker-compose.postgres-full.yml up --build -d
   docker compose -f docker-compose.postgres-full.yml logs -f migrate
   ```

The full migration discovers the source schema, copies rows into PostgreSQL, then creates indexes and foreign keys. The full PostgreSQL application is available at http://localhost:5003/ after the migration completes.

The verified full-data runtime uses the derived SQL dump. The official dataset links above are the authoritative source for obtaining the original data, while the schema and loader files document the intended relational representation and partial ingestion logic.

## Architecture stages

- Original course baseline: Flask + MySQL
- Docker stage: containerized Flask + MySQL with persistent storage
- PostgreSQL stage: PostgreSQL-compatible application and full-data migration
- Later Kubernetes/AWS work can be added as additional deployment stages without copying the application into separate folders.

## Project documentation

- [`PROJECT_GUIDE.md`](PROJECT_GUIDE.md) - verified behavior, commands, migration notes, and limitations
- [`START_HERE.md`](START_HERE.md) - earlier course-oriented walkthrough

## Data and privacy note

Only the synthetic `demo-*` records belong in the public repository. Keep the original download, SQL dump, generated exports, Docker volumes, and backups outside GitHub. Follow the AI-READI access terms and cite the dataset when using the real data.
