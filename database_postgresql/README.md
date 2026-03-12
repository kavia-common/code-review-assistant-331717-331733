# database_postgresql

PostgreSQL container for the Code Review Assistant.

This container provides:
- a Postgres instance (default DB `myapp`, user `appuser`, port `5000`)
- a migration runner (`migrate.sh`)
- a startup script (`startup.sh`) that initializes Postgres and applies migrations

## Migrations (required)

If the database is started without applying migrations, the schema can be empty (no `public.reviews`, `public.review_results`, etc.).  
In that state, the backend will fail requests like `POST /review` with a server error.

### Apply migrations

From this directory:

- `./startup.sh`
  - Starts Postgres (if not already running)
  - Creates the DB/user
  - Writes `db_connection.txt`
  - Runs `./migrate.sh`

Or, if Postgres is already running and `db_connection.txt` exists:

- `./migrate.sh`

### Verify schema

You can verify tables exist via:

- `psql postgresql://appuser:dbuser123@localhost:5000/myapp -c "\\dt"`

Expected tables include:
- `users`
- `reviews`
- `review_results`
- `schema_migrations`
