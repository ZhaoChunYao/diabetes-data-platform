# CS554 Healthcare Data Platform - Verified Project Guide

This guide describes the current merged project in this folder. It is the source of truth for the baseline version. The older README, HTML exports, and course notes contain historical material and may describe files or counts from earlier versions.

## What this project is

This is a MySQL-backed Flask website for exploring de-identified diabetes study data. The browser loads one of five HTML pages. Each page calls Flask REST endpoints. Flask runs SQL queries against the `project_554` MySQL database and returns JSON. The frontend then draws charts and tables with JavaScript/D3.

```text
Browser
  -> Flask in backend/server_unified.py
      -> MySQL database project_554
          -> participants, clinical, ECG, daily aggregate, and timeseries tables
```

The current runtime uses the preloaded SQL dump. The raw files under `dataset/` are not read by Flask at request time.

## Start the current version on Windows

### Prerequisites

- Python 3.8+
- MySQL 8.0+
- A MySQL client available as `mysql` if you want to import the dump from PowerShell
- At least 10 GB free disk space for the imported database

### Install Python packages

From this project folder:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

### Import the preloaded database

Create the database and import the SQL dump. The dump creates the tables and data used by the application.

```powershell
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS project_554 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
cmd /c "mysql -u root -p project_554 < sql_dump\project_554_complete.sql"
```

If the `mysql` command is not on PATH, use the full path to `mysql.exe` from your MySQL installation.

Optional configuration can be copied from `.env.example` to `.env`:

```powershell
Copy-Item .env.example .env
```

Set `DB_HOST`, `DB_USER`, `DB_PASS`, and `DB_NAME` in `.env` if your MySQL settings differ from the defaults.

### Start Flask

```powershell
.\.venv\Scripts\Activate.ps1
.\run_server.ps1
```

Open:

- http://localhost:5001/
- http://localhost:5001/feature1.html
- http://localhost:5001/feature2.html
- http://localhost:5001/feature3.html
- http://localhost:5001/feature4.html
- http://localhost:5001/feature5.html

The fixed server now serves these files from the actual `frontend/` directory.

## What each feature does

### Feature 1 - Data availability

Business purpose: answer “Which participants have which kinds of data?”

Implementation:

- `frontend/feature1.html` requests `/api/data_availability` and `/api/site_group_distribution`.
- Flask counts distinct participants in `participants`, `ecg_metadata`, `measurement`, `cgm_daily`, and `activity_daily`.
- The page displays overall counts and site/study-group bar charts.

### Feature 2 - Clinical measurements and conditions

Business purpose: compare clinical measurements and inspect condition records by study group.

Implementation:

- Measurement options come from `measurement.measurement_source_value`.
- Measurement summaries use `AVG`, `COUNT`, `MIN`, and `MAX` on `measurement.value_as_number`.
- Condition options, condition records, and condition counts use the `condition_occurrence` table from the SQL dump.
- The page is `frontend/feature2.html`.

Important limitation: `schema/01_metadata_tables.sql` defines the separate `conditions` and `participant_conditions` tables, but it does not define `condition_occurrence`. The SQL dump does define `condition_occurrence`, so the full dump is currently the working runtime source.

### Feature 3 - CGM trend explorer

Business purpose: show average glucose behavior across study days for selected groups, sites, ages, and day ranges.

Implementation:

- The page is `frontend/feature3.html`.
- It calls `/api/groups` and `/api/cgm/trend`.
- Flask reads from `cgm_daily`, joins `participants`, groups by `day_index`, and returns average glucose, TIR, TAR, TBR, measurement totals, and participant counts.
- The daily table exists so the page does not scan all raw CGM readings for every request.

### Feature 4 - CGM and activity correlation

Business purpose: compare glucose with activity or physiology, either for sampled individuals or at group level.

Implementation:

- The page is `frontend/feature4.html`.
- Single-participant mode calls `/api/feature4/single-participant` and reads raw tables such as `cgm_readings`, `hr_readings`, `sleep_readings`, `spo2_readings`, `stress_readings`, and `activity_readings`.
- Group mode uses daily tables and `/api/feature4/group-data` or `/api/feature4/correlation`.
- Correlations are calculated in Python with NumPy after SQL returns the paired values.

### Feature 5 - ECG and HbA1c analysis

Business purpose: display ECG measurements alongside HbA1c values and summarize QTc by study group.

Implementation:

- The page is `frontend/feature5.html`.
- `/api/feature5/ecg_hba1c` joins `ecg_metadata`, `measurement`, and `participants`.
- QT interval is calculated in the Flask query with the reverse Bazett formula.
- `/api/feature5/qtc_stats` calculates count, average, minimum, maximum, and standard deviation for QTc.

Important limitation: the current query joins ECG and HbA1c rows by participant. It does not yet choose the nearest HbA1c by date or enforce a time window. The page should therefore be described as a participant-level ECG/HbA1c comparison, not as a verified nearest-in-time clinical join.

## Database contents verified from the package

- The three schema files define 17 tables: 5 metadata, 6 daily aggregate, and 6 raw timeseries tables.
- The complete SQL dump contains those tables plus `condition_occurrence`, for 18 tables total.
- The six large timeseries tables have approximately 31.59 million rows in total according to their SQL dump auto-increment markers.
- The package data has 1,067 participant rows in `dataset/participants.tsv`; the SQL dump also contains 1,067 participant rows.
- The older claim of 905 participants is not used by this verified guide.

## Data and rebuild limitations

The application runs from the SQL dump. The included `dataset/` folder contains clinical and ECG source files, but the `dataset/processed` item is only a placeholder and is not a directory of processed CSV files.

`loaders/master_loader.py` is not a complete rebuild pipeline:

- participant loading is implemented;
- CGM and heart-rate loading are implemented for expected processed CSVs;
- measurement/ECG loading is only a placeholder;
- daily aggregate loading is only a message;
- sleep, SpO2, stress, and activity loaders are not implemented.

Therefore, “the website runs from the supplied SQL dump” is accurate. “The package can recreate the entire database from raw files using the loader” is not currently accurate.

## Verification checklist

After startup, check:

```powershell
Invoke-WebRequest http://localhost:5001/health | Select-Object -ExpandProperty Content
Invoke-WebRequest http://localhost:5001/api/groups | Select-Object -ExpandProperty Content
Invoke-WebRequest http://localhost:5001/api/data_availability | Select-Object -ExpandProperty Content
Invoke-WebRequest "http://localhost:5001/api/cgm/trend?group=healthy&start=1&end=3" | Select-Object -ExpandProperty Content
```

Expected behavior:

- `/health` reports a healthy MySQL connection.
- `/api/groups` returns study groups and participant counts.
- `/api/data_availability` returns modality coverage.
- `/api/cgm/trend` returns rows for study days.
- Each feature page loads without a missing `static/` directory error.

## Baseline scope for the next modernization phase

This baseline is intentionally still MySQL-based. The complete MySQL Docker version is the reference implementation. PostgreSQL is now available as a separate Phase 2 validation path and does not replace or delete the MySQL version. No cloud, Kubernetes, AWS, failover, or backup claim should be attached until those actions are actually run and documented.

## Phase 1 - Docker baseline

Phase 1 packages the existing Flask application and the complete MySQL database in a persistent volume. It is a portability exercise: the goal is to prove that the application can start on another machine with one command and that the full database survives an application restart.

The Phase 1 files are `Dockerfile`, `docker-compose.yml`, and `mysql/init/999_readiness.sql`. The complete SQL dump is mounted into the MySQL container at runtime rather than copied into the Flask image. The raw dataset and Python virtual environment are excluded from the image by `.dockerignore`.

The earlier `mysql/init/001_baseline.sql` is retained as the Phase 1A demo fixture, but it is not mounted by the default Compose file. The default Compose file now uses the full SQL dump and a separate `mysql_full_data` volume.

From this project folder:

```powershell
docker compose up --build
```

On the first run, MySQL imports `../sql_dump/project_554_complete.sql`. This can take a while. The health check allows up to 30 minutes for initialization, and the application is not considered ready until the final readiness marker has been written after the dump import completes. If an import is interrupted or the volume is left unhealthy, remove only the Docker test volume with `docker compose down -v` and start again; this does not touch a separate host MySQL installation.

Then check:

- http://localhost:5001/health
- http://localhost:5001/api/groups
- http://localhost:5001/api/cgm/trend?group=healthy&start=1&end=2

The MySQL data is stored in the named `mysql_full_data` volume. Stopping and starting the `app` service must not remove it. `docker compose down` keeps the volume. `docker compose down -v` deliberately removes the full test volume and forces the large dump to be imported again.

Phase 1 now verifies the full MySQL-backed application locally in containers. It does not claim cloud deployment, PostgreSQL migration, high availability, or backup/restore. Those belong to later phases and require their own evidence.

## Phase 2 - PostgreSQL migration

Phase 2 demonstrates that the application can use PostgreSQL without creating a second unrelated application. The MySQL version remains the full-data reference. The PostgreSQL version uses a separate Compose file, image, database volume, and representative seed dataset.

### What changed

- `backend/server_unified.py` now reads `DB_DRIVER`. The default is `mysql`, so the existing MySQL behavior remains the default.
- When `DB_DRIVER=postgres`, the backend uses `psycopg`, PostgreSQL connection settings, and dictionary rows from `psycopg.rows.dict_row`.
- Database-independent queries are shared by both modes.
- The few database-specific points are adapted, including PostgreSQL connections, the random ordering function (`RANDOM()` instead of MySQL `RAND()`), and the participant coverage filter that previously relied on a MySQL-style `HAVING` alias.
- `Dockerfile.postgres` installs the PostgreSQL driver while preserving the same Flask frontend and backend.
- `docker-compose.postgres.yml` starts PostgreSQL on host port `5433` and the PostgreSQL-backed Flask app on host port `5002`. These ports are separate from the MySQL version's `3307` and `5001` ports.
- `postgres/init/001_schema_and_seed.sql` creates the metadata, daily aggregate, and raw-timeseries table shapes needed by the main application paths. It inserts a small representative dataset and a final readiness marker.
- PostgreSQL stores its data in a separate named volume, `postgres_data`.

### Start the PostgreSQL version

Keep the MySQL version running if desired; the ports and volumes are separate. From this project folder:

```powershell
docker compose -f docker-compose.postgres.yml up --build -d
```

The PostgreSQL-backed application is available at:

- http://localhost:5002/
- http://localhost:5002/feature1.html
- http://localhost:5002/feature2.html
- http://localhost:5002/feature3.html
- http://localhost:5002/feature4.html
- http://localhost:5002/feature5.html

### Phase 2 acceptance checks

```powershell
docker compose -f docker-compose.postgres.yml ps
Invoke-WebRequest http://localhost:5002/health | Select-Object -ExpandProperty Content
Invoke-WebRequest http://localhost:5002/api/groups | Select-Object -ExpandProperty Content
Invoke-WebRequest "http://localhost:5002/api/cgm/trend?group=healthy&start=1&end=2" | Select-Object -ExpandProperty Content
Invoke-WebRequest http://localhost:5002/api/feature2/measurement_options | Select-Object -ExpandProperty Content
Invoke-WebRequest http://localhost:5002/api/feature5/qtc_stats | Select-Object -ExpandProperty Content
```

The health response should identify `postgres` as the backend. The API responses should contain representative rows rather than empty responses. The PostgreSQL container should report `healthy` only after the readiness marker has been inserted.

To verify persistence, restart only the PostgreSQL app container:

```powershell
docker compose -f docker-compose.postgres.yml restart app
Invoke-WebRequest http://localhost:5002/api/groups | Select-Object -ExpandProperty Content
```

The same groups should still be returned because application restart does not remove `postgres_data`.

### What Phase 2 does not claim

- It does not migrate the complete 1.49GB MySQL dump.
- It does not migrate all approximately 31.59 million timeseries rows.
- It does not prove that every production query has identical execution plans on both engines.
- It does not introduce high availability, replicas, backup/restore, Kubernetes, or AWS.
- PostgreSQL mode currently opens a short-lived connection per query instead of using a PostgreSQL connection pool. This is sufficient for the migration proof and should be revisited before a production deployment.

The honest Phase 2 statement is: “I adapted the shared Flask application to run against PostgreSQL, created equivalent representative schemas with keys and foreign-key constraints, and verified the main API paths using a persistent PostgreSQL container.” The full MySQL database remains the data-complete baseline until a separate full-data migration is performed.

## Phase 2B - Full PostgreSQL data migration

Because the later phases use PostgreSQL only, the representative Phase 2 database is not the final PostgreSQL baseline. Phase 2B migrates the complete running `project_554` MySQL database into a separate PostgreSQL volume.

### Migration design

`tools/migrate_mysql_to_postgres.py` connects to the running MySQL source and PostgreSQL target. It discovers the source schema from MySQL metadata, creates PostgreSQL tables, copies rows with PostgreSQL `COPY`, then creates indexes and foreign keys. It records row counts in `migration_row_counts` and writes `_migration_status.ready` only after the full process finishes.

The migration includes all tables present in the source database, including empty metadata tables. It does not read the external raw dataset and does not modify the MySQL source. The source MySQL container is reached through Docker Desktop's `host.docker.internal:3307` mapping.

### Start the full PostgreSQL migration

The full migration Compose file uses the existing `postgres_full_data` volume and host ports `5434` for PostgreSQL and `5003` for Flask. It is intentionally separate from the representative PostgreSQL Compose file (`postgres_data`, port `5433`, and port `5002`). The three Compose files now have explicit project names:

- `cs554-mysql` for `docker-compose.yml`.
- `cs554-pg-demo` for `docker-compose.postgres.yml`.
- `cs554-pg-full` for `docker-compose.postgres-full.yml`.

This matters because all three files live in the same folder and otherwise Docker Compose would derive the same project name from that folder. Since the files also use the same service name `db`, the later command could replace the earlier database container. The Compose files explicitly bind the old generated volume names, so separating the project names does not create new empty databases.

### First-time full migration order

From a state where the containers are stopped, start only the complete MySQL source database first. It may take up to 30 minutes on its first import:

```powershell
docker compose -f docker-compose.yml up -d db
docker compose -f docker-compose.yml ps
```

Wait for the MySQL `db` service to show `healthy`. Then start the full PostgreSQL target and migration:

```powershell
docker compose -f docker-compose.postgres-full.yml up --build -d
docker compose -f docker-compose.postgres-full.yml logs -f migrate
```

The MySQL and PostgreSQL containers now have different names and can run at the same time. The source MySQL uses host port `3307`; the full PostgreSQL target uses host port `5434`; and the Flask application uses host port `5003`.

```powershell
docker compose -f docker-compose.postgres-full.yml up --build -d
docker compose -f docker-compose.postgres-full.yml logs -f migrate
```

The first run can take a long time because it streams the complete database, including the large timeseries tables. The `migrate` service exits successfully after the marker is written; the Flask app then starts automatically.

Open the full PostgreSQL-backed application at:

- http://localhost:5003/
- http://localhost:5003/feature1.html
- http://localhost:5003/feature2.html
- http://localhost:5003/feature3.html
- http://localhost:5003/feature4.html
- http://localhost:5003/feature5.html

Check the migration and application:

```powershell
docker compose -f docker-compose.postgres-full.yml ps
Invoke-WebRequest http://localhost:5003/health | Select-Object -ExpandProperty Content
Invoke-WebRequest http://localhost:5003/api/groups | Select-Object -ExpandProperty Content
Invoke-WebRequest "http://localhost:5003/api/cgm/trend?group=healthy&start=1&end=3" | Select-Object -ExpandProperty Content
Invoke-WebRequest http://localhost:5003/api/feature5/qtc_stats | Select-Object -ExpandProperty Content
```

The health response should report `postgres`, and the migration service should show `Exited (0)`. The application will not start until the migration service completes successfully.

### Re-running and persistence

After a successful migration, running the same Compose command again skips the import because `_migration_status.ready` already exists. Restarting the app or database does not remove `postgres_full_data`.

If the first migration is interrupted and the target is left partial, reset only this PostgreSQL test environment and rerun:

```powershell
docker compose -f docker-compose.postgres-full.yml down -v
docker compose -f docker-compose.postgres-full.yml up --build -d
```

This removes only the PostgreSQL full-migration volume. It does not delete the full MySQL source volume or the external dataset.

### PostgreSQL-only startup after migration

After `_migration_status.ready` exists, the MySQL source can be stopped. Start the PostgreSQL database and Flask app without rerunning the migration service:

```powershell
docker compose -f docker-compose.postgres-full.yml up -d db
docker compose -f docker-compose.postgres-full.yml up -d --no-deps app
```

Do not use `down -v` unless the full PostgreSQL data is intentionally being discarded.

### Phase 2B acceptance standard

Phase 2B is complete only when:

- The migration service exits successfully.
- `_migration_status` contains `ready`.
- `migration_row_counts` contains every source table.
- PostgreSQL has the migrated primary keys, indexes, and foreign keys.
- The five feature pages work against the full PostgreSQL data.
- Feature 4 can read migrated raw timeseries rows.
- Restarting the PostgreSQL stack preserves the data.

Only after these checks should Phase 3 deploy PostgreSQL under Kubernetes and CloudNativePG. Phase 3 and later must use `docker-compose.postgres-full.yml`'s PostgreSQL data model, not the representative seed database.
