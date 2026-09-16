# Synthetic demo data

The runnable sample in this repository is synthetic. It uses four `demo-*` participants and a small number of daily and timeseries records so that the application can be demonstrated without distributing research data.

The SQL fixtures are kept with their database initialization files:

- MySQL fixture: `docker/mysql/init/001_baseline.sql`
- PostgreSQL fixture: `docker/postgres/init/001_schema_and_seed.sql`

These records are not intended to reproduce the AI-READI study or support research conclusions. Obtain the original dataset from the [official AI-READI sources](https://docs.aireadi.org/) if real data is needed.
