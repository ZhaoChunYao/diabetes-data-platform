# Phase 0 Project Guide

This version is the corrected local MySQL baseline. Flask serves the files from `frontend/`, connects to the `project_554` MySQL database, and exposes the five feature pages and their API endpoints.

The application expects an already populated database. The schema files in `schema/` document the intended metadata, daily aggregate, and timeseries layers. The raw-to-database loader is not complete enough to reproduce the full SQL dump automatically, so the original data and SQL dump remain external.

Start the server with:

```powershell
.\run_server.ps1
```

The later Docker/PostgreSQL deployment is documented in the next repository version.
