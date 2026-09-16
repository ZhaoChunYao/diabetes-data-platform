# Diabetes Data Platform - Phase 0 Original

This is the corrected MySQL-backed CS554 course application. It provides five browser features backed by a Flask API and a relational `project_554` database.

## Data source

The project is based on the [AI-READI Flagship Dataset](https://aireadi.org/) for type 2 diabetes. See the [official dataset documentation](https://docs.aireadi.org/) and [access portal](https://fairhub.io/datasets/1/access/login) for the original data and its access terms.

Real research data and the course SQL dump are not included in this repository. The schema is documented in [`schema/`](schema/) and [`DATABASE_DESIGN_REPORT.md`](DATABASE_DESIGN_REPORT.md). The current loader is only a partial implementation; the verified application runtime uses an already populated MySQL database.

## Run locally

1. Create the `project_554` MySQL database from an authorized compatible SQL dump.
2. Install the Python dependencies:

   ```powershell
   python -m pip install -r requirements.txt
   ```

3. Configure `.env` from `.env.example`.
4. Start the server:

   ```powershell
   .\run_server.ps1
   ```

Open http://localhost:5001/ and the five feature pages under the same address.

This phase is the original local application with the verified frontend path fixes. Docker and PostgreSQL deployment are introduced in the later `phase2-docker-postgres` version.

## Privacy

Keep the original dataset, SQL dump, exports, and database backups outside GitHub. Use the official AI-READI access terms when obtaining or sharing real data.
